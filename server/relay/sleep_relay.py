"""Sleep co-op relay: friends play together without a VPN, port forwarding or router luck.

The host still runs the game (the ENet server, the mission, the infected) on their own PC. What changes is how
everyone reaches it: the host and every friend only ever send *outwards* to this server, which passes the game's
UDP packets between them unchanged. Routers allow replies to traffic a PC sent itself, so nothing has to be opened.

    host game ── TCP control (CONTROL_PORT) ──────────────► relay: "hello"   ◄── "room P"
    friend ──── ENet to <server>:P (one UDP port per room) ► relay
    relay ───── "open Q" (a UDP port for that friend) ─────► host
    host game ── "SLR1<token>" from its own game socket ───► <server>:Q   (the relay learns where the host's router
                                                                          sends that socket's traffic from)
    friend ◄──► P ◄──► relay ◄──► Q ◄──► host                (every packet, both ways, until the friend goes quiet)

Each friend gets their own Q, so the host's ENet sees one address per friend, exactly as on a LAN.

    python3 sleep_relay.py [--public-ip 15.235.246.87] [--status 127.0.0.1:8480]

The status address answers GET /rooms (JSON) for the website. Only standard library modules are used.
"""
import argparse
import asyncio
import json
import logging
import secrets
import time

CONTROL_PORT = 25109
ROOM_PORTS = range(25110, 25160)       # 50 rooms at once
CLIENT_PORTS = range(25200, 25600)     # 400 friends at once
MAX_CLIENTS_PER_ROOM = 8               # the game takes 4 friends; ENet retries count as the same friend
MAX_ROOMS_PER_IP = 3
CLIENT_IDLE = 40.0                     # seconds without a packet from the friend
HOST_IDLE = 60.0                       # seconds without a control line from the host (it pings every 15)
MAGIC = b"SLR1"
LINE_LIMIT = 2048

log = logging.getLogger("sleep-relay")


def now() -> float:
    return time.monotonic()


class Ports:
    def __init__(self, ports: range):
        self.free = list(ports)
        self.used = set()

    def take(self):
        while self.free:
            p = self.free.pop(0)
            if p not in self.used:
                self.used.add(p)
                return p
        return None

    def give(self, p: int) -> None:
        if p in self.used:
            self.used.discard(p)
            self.free.append(p)


class Udp(asyncio.DatagramProtocol):
    def __init__(self, on_packet):
        self.on_packet = on_packet
        self.transport = None

    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        try:
            self.on_packet(data, addr)
        except Exception:  # one bad packet never stops the relay
            log.exception("packet handler")

    def error_received(self, exc):
        pass


class Client:
    def __init__(self, addr, q: int):
        self.addr = addr
        self.q = q
        self.sock: Udp = None
        self.host_addr = None
        self.pending = []
        self.seen = now()


class Room:
    def __init__(self, relay, writer, name: str, version: str):
        self.relay = relay
        self.writer = writer
        self.name = name
        self.version = version
        self.token = secrets.token_hex(8)
        self.port = 0
        self.sock: Udp = None
        self.clients = {}          # friend address -> Client
        self.by_q = {}             # Q -> Client
        self.created = time.time()
        self.seen = now()
        self.closed = False
        self.ip = writer.get_extra_info("peername")[0]

    def send(self, msg: dict) -> None:
        if self.closed:
            return
        try:
            self.writer.write((json.dumps(msg, separators=(",", ":")) + "\n").encode())
        except Exception:
            pass

    # ---- friend → host
    def from_friend(self, data: bytes, addr) -> None:
        c = self.clients.get(addr)
        if c is None:
            if len(self.clients) >= MAX_CLIENTS_PER_ROOM:
                return
            q = self.relay.client_ports.take()
            if q is None:
                return
            c = Client(addr, q)
            self.clients[addr] = c
            self.by_q[q] = c
            asyncio.ensure_future(self._open(c))
        c.seen = now()
        if c.host_addr is not None and c.sock is not None and c.sock.transport is not None:
            c.sock.transport.sendto(data, c.host_addr)
        elif len(c.pending) < 32:
            c.pending.append(data)

    async def _open(self, c: Client) -> None:
        loop = asyncio.get_running_loop()
        try:
            _, proto = await loop.create_datagram_endpoint(lambda: Udp(lambda d, a: self.from_host(c, d, a)),
                                                           local_addr=(self.relay.bind, c.q))
        except OSError as e:
            log.warning("room %s: port %d unavailable (%s)", self.port, c.q, e)
            self.drop(c, tell=False)
            return
        c.sock = proto
        if self.closed or self.by_q.get(c.q) is not c:
            proto.transport.close()
            return
        self.send({"t": "open", "port": c.q})
        log.info("room %d: friend %s:%d -> port %d", self.port, c.addr[0], c.addr[1], c.q)

    # ---- host → friend
    def from_host(self, c: Client, data: bytes, addr) -> None:
        if data[:4] == MAGIC:
            if data[4:].decode(errors="replace") != self.token:
                return
            first = c.host_addr is None
            c.host_addr = addr
            if first:
                for d in c.pending:
                    c.sock.transport.sendto(d, addr)
                c.pending.clear()
                self.send({"t": "bound", "port": c.q})
            return
        if addr != c.host_addr or self.sock is None or self.sock.transport is None:
            return
        self.sock.transport.sendto(data, c.addr)

    def drop(self, c: Client, tell=True) -> None:
        self.clients.pop(c.addr, None)
        self.by_q.pop(c.q, None)
        if c.sock is not None and c.sock.transport is not None:
            c.sock.transport.close()
        self.relay.client_ports.give(c.q)
        if tell:
            self.send({"t": "close", "port": c.q})

    def sweep(self) -> None:
        t = now()
        for c in list(self.clients.values()):
            if t - c.seen > CLIENT_IDLE:
                log.info("room %d: friend %s:%d went quiet", self.port, c.addr[0], c.addr[1])
                self.drop(c)

    def close(self) -> None:
        if self.closed:
            return
        for c in list(self.clients.values()):
            self.drop(c, tell=False)
        self.closed = True
        if self.sock is not None and self.sock.transport is not None:
            self.sock.transport.close()
        if self.port:
            self.relay.room_ports.give(self.port)
        try:
            self.writer.close()
        except Exception:
            pass

    def info(self) -> dict:
        return {"name": self.name, "version": self.version, "friends": len(self.clients),
                "minutes": int((time.time() - self.created) // 60)}


class Relay:
    def __init__(self, public_ip: str, bind: str = "0.0.0.0"):
        self.public_ip = public_ip
        self.bind = bind
        self.rooms = {}            # room port -> Room
        self.room_ports = Ports(ROOM_PORTS)
        self.client_ports = Ports(CLIENT_PORTS)

    async def control(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        room = None
        peer = writer.get_extra_info("peername")
        try:
            line = await asyncio.wait_for(reader.readline(), 10)
            hello = json.loads(line[:LINE_LIMIT] or b"{}")
            if not isinstance(hello, dict) or hello.get("t") != "hello":
                return
            name = "".join(ch for ch in str(hello.get("name", "Host"))[:24] if ch.isprintable())
            version = str(hello.get("v", "?"))[:16]
            if sum(1 for r in self.rooms.values() if r.ip == peer[0]) >= MAX_ROOMS_PER_IP:
                writer.write(b'{"t":"full","why":"too many rooms from this address"}\n')
                return
            port = self.room_ports.take()
            if port is None:
                writer.write(b'{"t":"full","why":"the relay is full"}\n')
                return
            room = Room(self, writer, name, version)
            loop = asyncio.get_running_loop()
            try:
                _, proto = await loop.create_datagram_endpoint(lambda: Udp(lambda d, a: room.from_friend(d, a)),
                                                               local_addr=(self.bind, port))
            except OSError:
                self.room_ports.give(port)
                writer.write(b'{"t":"full","why":"no free port"}\n')
                return
            room.port = port
            room.sock = proto
            self.rooms[port] = room
            room.send({"t": "room", "port": port, "token": room.token, "ip": self.public_ip, "you": peer[0]})
            log.info("room %d opened by %s (%s, v%s)", port, peer[0], name, version)
            while True:
                line = await asyncio.wait_for(reader.readline(), HOST_IDLE)
                if not line:
                    break
                room.seen = now()
                try:
                    msg = json.loads(line[:LINE_LIMIT])
                except ValueError:
                    continue
                if isinstance(msg, dict) and msg.get("t") == "ping":
                    room.send({"t": "pong", "friends": len(room.clients)})
                elif isinstance(msg, dict) and msg.get("t") == "bye":
                    break
        except (asyncio.TimeoutError, ConnectionError, ValueError):
            pass
        finally:
            if room is not None:
                self.rooms.pop(room.port, None)
                room.close()
                log.info("room %d closed", room.port)
            else:
                try:
                    writer.close()
                except Exception:
                    pass

    async def sweeper(self) -> None:
        while True:
            await asyncio.sleep(5)
            for r in list(self.rooms.values()):
                r.sweep()

    async def status(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        try:
            await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), 5)
            body = json.dumps({"rooms": [r.info() for r in self.rooms.values()],
                               "players": sum(1 + len(r.clients) for r in self.rooms.values())}).encode()
            writer.write(b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nCache-Control: no-store\r\n"
                         b"Content-Length: " + str(len(body)).encode() + b"\r\nConnection: close\r\n\r\n" + body)
            await writer.drain()
        except Exception:
            pass
        finally:
            writer.close()


async def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--public-ip", default="")
    ap.add_argument("--bind", default="0.0.0.0")
    ap.add_argument("--status", default="127.0.0.1:8480", help="host:port for GET /rooms, or empty")
    a = ap.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    relay = Relay(a.public_ip, a.bind)
    server = await asyncio.start_server(relay.control, a.bind, CONTROL_PORT)
    if a.status:
        h, p = a.status.rsplit(":", 1)
        await asyncio.start_server(relay.status, h, int(p))
    log.info("Sleep relay: control TCP %d, rooms UDP %d-%d, friends UDP %d-%d", CONTROL_PORT,
             ROOM_PORTS.start, ROOM_PORTS.stop - 1, CLIENT_PORTS.start, CLIENT_PORTS.stop - 1)
    asyncio.ensure_future(relay.sweeper())
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
