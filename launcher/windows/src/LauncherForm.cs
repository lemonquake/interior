using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Sleep.Launcher
{
    /// <summary>
    /// The launcher window: key art of Sitio Kalinaw, the title, what's new in the release, the official servers, and one
    /// big button that installs, updates or plays. Drawn by hand at 1180x680 logical pixels, scaled to the monitor's DPI.
    /// (1.5.0) INSTALL first asks where the game goes (a drive or any folder; always "AzAz Games\Sleep"
    /// inside it), and a Settings panel moves, checks or removes the game.
    /// </summary>
    sealed class LauncherForm : Form
    {
        public const string WindowTitle = "Sleep";
        const float W = 1180, H = 680, M = 64, BtnW = 280, BtnH = 80;

        enum Mode { Checking, Install, Update, Ready, Working, Error, Playing }
        enum Overlay { None, Install, Move, Settings }

        // The panel over the window: where to install (or move) the game, or Settings.
        Overlay _overlay;
        string _pickDir, _pickProblem;
        bool _pickSoft, _pickShortcut = true, _moving;
        long _pickFree = -1, _pickNeed;
        List<DriveInfo> _drives = new List<DriveInfo>();

        readonly string _baseUrl;
        readonly Updater _u;
        Manifest _remote;
        Mode _mode = Mode.Checking;
        string _status = "Checking for updates…", _detail = "Connecting to the Sleep server";
        Color _statusColor = Ui.Text;
        UpdateProgress _p;
        CancellationTokenSource _cts;
        Process _game;
        bool _offline;
        // Squads open on the relay (/api/rooms)
        List<Dictionary<string, object>> _servers;
        bool? _serversUp;
        int _onlineCount;

        float S = 1f;
        readonly Dictionary<string, RectangleF> _hit = new Dictionary<string, RectangleF>();
        string _hover, _pressed;
        Bitmap _bgCache;
        readonly Image _art;
        readonly Image _icon;
        readonly System.Windows.Forms.Timer _anim = new System.Windows.Forms.Timer { Interval = 50 };
        readonly System.Windows.Forms.Timer _poll = new System.Windows.Forms.Timer { Interval = 20000 };
        int _tick, _pollCount;
        float _serversBottom = 200;
        readonly Font _fTitle = Ui.Serif(132), _fSub = Ui.Condensed(38), _fBtn = Ui.Condensed(34), _fHead = Ui.Semi(13),
            _fBody = Ui.Regular(15.5f), _fBodyB = Ui.Semi(15.5f), _fStatus = Ui.Semi(21), _fSmall = Ui.Regular(13.5f), _fBy = Ui.Regular(21),
            _fPanel = Ui.Condensed(32), _fBtnS = Ui.Condensed(22);

        public LauncherForm(string baseUrl)
        {
            _baseUrl = baseUrl;
            _u = new Updater(baseUrl, Program.InstallDir);
            Text = WindowTitle;
            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.CenterScreen;
            if (Program.Args.ContainsKey("snap")) { StartPosition = FormStartPosition.Manual; Location = new Point(-4000, -4000); ShowInTaskbar = false; }
            BackColor = Ui.Bg;
            DoubleBuffered = true;
            KeyPreview = true;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
            using (var s = typeof(Ui).Assembly.GetManifestResourceStream("app.ico")) Icon = new Icon(s);
            _art = Ui.Resource("background.jpg");
            _icon = Icon.ToBitmap();
            ApplyDpi(DeviceDpi);
            _anim.Tick += (s, e) => { _tick++; Invalidate(); };
            _poll.Tick += async (s, e) => await PollAsync();
            _u.Progress += p => { _p = p; };
        }

        // Snap (test) runs never take the keyboard focus from whatever the person at the PC is doing.
        protected override bool ShowWithoutActivation => Program.Args.ContainsKey("snap");

        protected override CreateParams CreateParams
        {
            get
            {
                var cp = base.CreateParams;
                cp.ClassStyle |= 0x20000;  // CS_DROPSHADOW
                return cp;
            }
        }

        void ApplyDpi(int dpi)
        {
            S = dpi / 96f;
            ClientSize = new Size((int)Math.Round(W * S), (int)Math.Round(H * S));
            _bgCache?.Dispose();
            _bgCache = null;
        }

        protected override void OnDpiChanged(DpiChangedEventArgs e)
        {
            base.OnDpiChanged(e);
            ApplyDpi(e.DeviceDpiNew);
            Invalidate();
        }

        protected override async void OnShown(EventArgs e)
        {
            base.OnShown(e);
            try
            {
                int round = 2;  // DWMWCP_ROUND: rounded corners on Windows 11
                Native.DwmSetWindowAttribute(Handle, 33, ref round, sizeof(int));
            }
            catch (Exception) { }
            _anim.Start();
            _poll.Start();
            _ = RefreshServersAsync();
            await CheckAsync();
            if (Program.Args.TryGetValue("snap", out var snap)) await SnapAsync(snap);
        }

        /// <summary>
        /// --snap=file.png [--snap-panel=install|move|settings] [--snap-pick=place [--snap-confirm]] [--snap-wait=ms]:
        /// saves a picture of the window and closes it; --snap-confirm presses the panel's INSTALL or MOVE and waits for
        /// it (release screenshots and tests; run with --portable --data-dir=X so nothing of the player's is touched).
        /// </summary>
        async Task SnapAsync(string file)
        {
            switch (Program.Arg("snap-panel", ""))
            {
                case "install": OpenPicker(Overlay.Install); break;
                case "move": OpenPicker(Overlay.Move); break;
                case "settings": _overlay = Overlay.Settings; break;
            }
            if (Program.Args.TryGetValue("snap-pick", out var place)) SetPick(place);
            if (Program.Args.ContainsKey("snap-confirm")) await ConfirmPickAsync();
            await Task.Delay(int.Parse(Program.Arg("snap-wait", "3000")));
            using (var bmp = new Bitmap(ClientSize.Width, ClientSize.Height))
            {
                DrawToBitmap(bmp, ClientRectangle);
                bmp.Save(file, System.Drawing.Imaging.ImageFormat.Png);
            }
            Close();
        }

        // ------------------------------------------------------------------ state

        async Task CheckAsync(bool quiet = false)
        {
            if (!quiet) SetMode(Mode.Checking, "Checking for updates…", "Connecting to the Sleep server");
            try
            {
                var m = await _u.FetchAsync(CancellationToken.None);
                _remote = m;
                _offline = false;
                var next = await _u.FetchNewLauncherAsync(m, Program.SelfPath, CancellationToken.None);
                if (next != null)
                {
                    SetMode(Mode.Working, "Updating the launcher…", "Launcher " + m.Launcher.Version);
                    var self = Program.SelfPath;
                    File.Move(self, self + ".old");
                    File.Move(next, self);
                    Process.Start(new ProcessStartInfo(self, "--updated") { UseShellExecute = false });
                    Application.Exit();
                    return;
                }
                ShowLocalState();
            }
            catch (Exception ex)
            {
                _offline = true;
                var have = _u.InstalledVersion();
                if (have != "")
                    SetMode(Mode.Ready, "Ready to play", "Offline: the update server cannot be reached (" + Short(ex) + "). You can still play version " + have + ".");
                else if (!quiet)
                    SetMode(Mode.Error, "Can't reach the Sleep server", Short(ex) + " Check your internet connection, then try again.", Ui.Danger);
            }
        }

        void ShowLocalState()
        {
            var m = _remote;
            var have = _u.InstalledVersion(m);
            if (_game != null && !_game.HasExited)
            {
                SetMode(Mode.Playing, "Sleep is running", have != m.Version ? "Update " + m.Version + " is ready: close the game to install it." : "Have a good match.");
                return;
            }
            if (have == "")
            {
                long dl = _u.PendingDownload(m, false);
                SetMode(Mode.Install, "Ready to install", string.Format("Version {0} · {1} download · {2} on disk", m.Version, Updater.Size(dl), Updater.Size(m.Size)));
            }
            else if (have != m.Version)
            {
                long dl = _u.PendingDownload(m, false);
                SetMode(Mode.Update, "Update available", string.Format("Version {0} → {1} · {2} to download", have, m.Version, Updater.Size(Math.Max(dl, 1))));
            }
            else SetMode(Mode.Ready, "Ready to play", "Version " + m.Version + " is installed and up to date.");
        }

        void SetMode(Mode m, string status, string detail, Color? color = null)
        {
            _mode = m;
            _status = status;
            _detail = detail;
            _statusColor = color ?? Ui.Text;
            Invalidate();
        }

        async Task RunUpdateAsync(bool verify)
        {
            if (_remote == null) { await CheckAsync(); if (_remote == null) return; }
            _cts = new CancellationTokenSource();
            _p = null;
            SetMode(Mode.Working, verify ? "Checking game files…" : (_u.InstalledVersion(_remote) == "" ? "Installing Sleep…" : "Updating Sleep…"), "Starting");
            try
            {
                await Task.Run(() => _u.ApplyAsync(_remote, verify, _cts.Token));
                Program.InstallDir = _u.InstallDir;
                Setup.EnsureShortcuts(Program.InstalledLauncher);
                ShowLocalState();
                if (verify) _detail = "All files checked: " + _detail;
                FlashIfInactive();
            }
            catch (OperationCanceledException)
            {
                SetMode(Mode.Error, "Paused", "The download stopped. Choose RESUME to continue where it left off.", Ui.Accent);
            }
            catch (Exception ex)
            {
                SetMode(Mode.Error, "Something went wrong", Short(ex), Ui.Danger);
            }
            finally { _cts = null; }
        }

        void Launch()
        {
            var exe = _u.GameExe(_remote);
            if (!File.Exists(exe)) { _ = CheckAsync(); return; }
            try
            {
                Watch(Process.Start(new ProcessStartInfo(exe) { WorkingDirectory = Path.GetDirectoryName(exe), UseShellExecute = false }), exe);
                SetMode(Mode.Playing, "Sleep is running", "Have a good match.");
                WindowState = FormWindowState.Minimized;
            }
            catch (Exception ex)
            {
                SetMode(Mode.Error, "The game did not start", Short(ex), Ui.Danger);
            }
        }

        void Watch(Process p, string exe)
        {
            _game = p;
            _game.EnableRaisingEvents = true;
            _game.Exited += (s, e) => BeginInvoke((Action)(async () =>
            {
                int code = 0;
                try { code = p.ExitCode; } catch (Exception) { }
                _game = null;
                // After a crash the game can restart itself on Safe graphics (OpenGL): follow the new process
                // instead of coming back with PLAY while it is starting.
                await Task.Delay(2000);
                var again = FindGame(exe);
                if (again != null) { Watch(again, exe); return; }
                if (WindowState == FormWindowState.Minimized) WindowState = FormWindowState.Normal;
                Activate();
                await CheckAsync(true);
                if (code != 0 && _mode == Mode.Ready)
                    SetMode(Mode.Ready, "Sleep closed unexpectedly",
                        string.Format("Error 0x{0:X8}. Press PLAY again; if it keeps crashing, the game switches itself to Safe graphics (Settings > Graphics).", code),
                        Ui.Danger);
            }));
        }

        static Process FindGame(string exe)
        {
            foreach (var q in Process.GetProcessesByName(Path.GetFileNameWithoutExtension(exe)))
            {
                try { if (string.Equals(q.MainModule.FileName, exe, StringComparison.OrdinalIgnoreCase)) return q; }
                catch (Exception) { }
            }
            return null;
        }

        async Task PollAsync()
        {
            _pollCount++;
            await RefreshServersAsync();
            if (_pollCount % 15 == 0 && (_mode == Mode.Ready || _mode == Mode.Playing || _offline))
            {
                var before = _remote?.Version;
                await CheckAsync(true);
                if (_remote != null && before != null && _remote.Version != before) FlashIfInactive();
            }
        }

        async Task RefreshServersAsync()
        {
            try
            {
                // Squads hosting through the Sleep relay right now (server/relay/sleep_relay.py, GET /rooms).
                var text = await _u.GetStringAsync(_baseUrl.TrimEnd('/') + "/api/rooms", CancellationToken.None);
                var d = Json.Obj(Json.Parse(text));
                _servers = Json.Arr(d, "rooms").Cast<object>().Select(Json.Obj).Take(6).ToList();
                _onlineCount = (int)Json.Long(d, "players");
                _serversUp = true;
            }
            catch (Exception) { _serversUp = false; _servers = null; }
            Invalidate();
        }

        void FlashIfInactive()
        {
            if (Form.ActiveForm != this) Native.FlashWindow(Handle, true);
        }

        static string Short(Exception e)
        {
            while (e is AggregateException && e.InnerException != null) e = e.InnerException;
            if (e is System.Net.Http.HttpRequestException && e.InnerException != null) return e.InnerException.Message.TrimEnd('.') + ".";
            return e.Message;
        }

        // ------------------------------------------------------------------ input

        PointF Logical(Point p) => new PointF(p.X / S, p.Y / S);

        string HitAt(PointF p)
        {
            foreach (var kv in _hit) if (kv.Value.Contains(p)) return kv.Key;
            return null;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            var h = HitAt(Logical(e.Location));
            if (h != _hover) { _hover = h; Cursor = h != null ? Cursors.Hand : Cursors.Default; Invalidate(); }
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            base.OnMouseLeave(e);
            _hover = null;
            Invalidate();
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            var lp = Logical(e.Location);
            var h = HitAt(lp);
            if (h == null && lp.Y < 48 && e.Button == MouseButtons.Left)
            {
                Native.ReleaseCapture();
                Native.SendMessage(Handle, 0xA1, (IntPtr)2, IntPtr.Zero);  // drag by the title bar
                return;
            }
            _pressed = h;
            Invalidate();
        }

        protected override async void OnMouseUp(MouseEventArgs e)
        {
            base.OnMouseUp(e);
            var h = HitAt(Logical(e.Location));
            var was = _pressed;
            _pressed = null;
            Invalidate();
            if (h == null || h != was || e.Button != MouseButtons.Left) return;
            if (h.StartsWith("drive:")) { SetPick(h.Substring(6)); return; }
            switch (h)
            {
                case "close": Close(); break;
                case "min": WindowState = FormWindowState.Minimized; break;
                case "main": await MainButtonAsync(); break;
                case "settings": _overlay = Overlay.Settings; Invalidate(); break;
                case "folder": if (Directory.Exists(_u.InstallDir)) Process.Start("explorer.exe", "\"" + _u.InstallDir + "\""); break;
                case "website": Process.Start(Program.Website); break;
                // Location panel
                case "ov_close": case "ov_cancel": CloseOverlay(); break;
                case "browse": case "field": Browse(); break;
                case "shortcut": _pickShortcut = !_pickShortcut; Invalidate(); break;
                case "ov_ok": await ConfirmPickAsync(); break;
                // Settings
                case "s_move": OpenPicker(Overlay.Move); break;
                case "s_shortcut": Setup.SetDesktopShortcut(!Setup.DesktopShortcutWanted); Invalidate(); break;
                case "s_verify": CloseOverlay(); await RunUpdateAsync(true); break;
                case "s_uninstall": if (Setup.Uninstall() == 0) Close(); break;
            }
        }

        protected override async void OnKeyDown(KeyEventArgs e)
        {
            base.OnKeyDown(e);
            if (_overlay == Overlay.None) return;
            if (e.KeyCode == Keys.Escape) CloseOverlay();
            else if (e.KeyCode == Keys.Enter && _overlay != Overlay.Settings) await ConfirmPickAsync();
        }

        void CloseOverlay()
        {
            // Move is opened from Settings: going back returns there.
            _overlay = _overlay == Overlay.Move ? Overlay.Settings : Overlay.None;
            Invalidate();
        }

        async Task MainButtonAsync()
        {
            switch (_mode)
            {
                case Mode.Install: OpenPicker(Overlay.Install); break;
                case Mode.Update: await RunUpdateAsync(false); break;
                case Mode.Ready: Launch(); break;
                case Mode.Working: _cts?.Cancel(); break;
                case Mode.Error:
                    if (_remote != null && _status == "Paused") await RunUpdateAsync(false);
                    else await CheckAsync();
                    break;
            }
        }

        // ------------------------------------------------------------------ install location

        bool Busy => _mode == Mode.Working || _mode == Mode.Playing || _mode == Mode.Checking;

        void OpenPicker(Overlay kind)
        {
            if (kind == Overlay.Move && (Busy || _u.InstalledVersion(_remote) == "")) return;
            _overlay = kind;
            _drives = Drives();
            _pickShortcut = Setup.DesktopShortcutWanted;
            _pickNeed = kind == Overlay.Move ? FolderBytes(_u.InstallDir) : _remote?.Size ?? 0;
            SetPick(_u.InstallDir);
        }

        /// <summary>The game folder for a place the player picked, and whether it can go there.</summary>
        void SetPick(string place)
        {
            _pickProblem = null;
            _pickSoft = false;
            _pickFree = -1;
            try { _pickDir = Program.GameFolderIn(place); }
            catch (Exception) { _pickProblem = "That isn't a folder Sleep can use. Pick another one."; Invalidate(); return; }
            var root = Path.GetPathRoot(_pickDir);
            try { if (!root.StartsWith(@"\\")) _pickFree = new DriveInfo(root).AvailableFreeSpace; }
            catch (Exception) { }
            bool same = string.Equals(_pickDir, Path.GetFullPath(_u.InstallDir).TrimEnd('\\'), StringComparison.OrdinalIgnoreCase);
            if (root.StartsWith(@"\\"))
                _pickProblem = "Pick a drive on this PC: the game can't run from a network folder.";
            else if (_overlay == Overlay.Move && same)
            { _pickProblem = "The game is in this folder now. Pick another drive or folder."; _pickSoft = true; }
            else if (_overlay == Overlay.Move && _pickDir.StartsWith(Path.GetFullPath(_u.InstallDir).TrimEnd('\\') + "\\", StringComparison.OrdinalIgnoreCase))
                _pickProblem = "That folder is inside the game's current folder. Pick another one.";
            else if (!Setup.CanWrite(_pickDir))
                _pickProblem = "Windows needs administrator rights to write there. Pick another drive or folder.";
            else if (_overlay == Overlay.Move && Directory.Exists(_pickDir) && Directory.GetFileSystemEntries(_pickDir).Length > 0)
                _pickProblem = "There are already files in " + _pickDir + ". Pick another place.";
            // (A half-finished install there reuses its files, so the updater's own space check is the one that counts.)
            else if (_pickFree >= 0 && _pickNeed > 0 && !File.Exists(Path.Combine(_pickDir, ".launcher", "state.json")) && _pickFree < _pickNeed + (256L << 20))
                _pickProblem = string.Format("Not enough space on {0}: {1} needed, {2} free.", root.TrimEnd('\\'), Updater.Size(_pickNeed), Updater.Size(_pickFree));
            Invalidate();
        }

        void Browse()
        {
            var start = _pickDir;
            while (start != null && !Directory.Exists(start)) start = Path.GetDirectoryName(start);
            var title = _overlay == Overlay.Move ? "Move Sleep to" : "Install Sleep in";
            var picked = FolderPicker.Pick(this, title + " (an AzAz Games\\Sleep folder is made inside)", start);
            if (picked != null) SetPick(picked);
        }

        async Task ConfirmPickAsync()
        {
            if (_pickProblem != null || _pickDir == null) return;
            var dir = _pickDir;
            var kind = _overlay;
            _overlay = Overlay.None;
            if (kind == Overlay.Install)
            {
                _u.InstallDir = dir;
                Program.InstallDir = dir;
                Setup.SetDesktopShortcut(_pickShortcut);
                await RunUpdateAsync(false);
            }
            else if (kind == Overlay.Move) await MoveAsync(dir);
        }

        async Task MoveAsync(string dest)
        {
            var from = _u.InstallDir;
            _moving = true;
            _p = null;
            SetMode(Mode.Working, "Moving Sleep…", "To " + dest);
            try
            {
                await Task.Run(() => Setup.MoveGame(from, dest, p => _p = p));
                _u.InstallDir = dest;
                Program.InstallDir = dest;
                if (_remote != null) ShowLocalState();
                else SetMode(Mode.Ready, "Ready to play", "");
                _detail = "Moved to " + dest + ". " + _detail;
                FlashIfInactive();
            }
            catch (Exception ex)
            {
                SetMode(Mode.Error, "The game could not be moved", Short(ex) + " It is still in " + from + ".", Ui.Danger);
            }
            finally { _moving = false; Invalidate(); }
        }

        static List<DriveInfo> Drives()
        {
            var list = new List<DriveInfo>();
            try
            {
                foreach (var d in DriveInfo.GetDrives())
                    try { if (d.DriveType == DriveType.Fixed && d.IsReady) list.Add(d); } catch (Exception) { }
            }
            catch (Exception) { }
            return list.Take(5).ToList();
        }

        static long FolderBytes(string dir)
        {
            try { return Directory.EnumerateFiles(dir, "*", SearchOption.AllDirectories).Sum(f => new FileInfo(f).Length); }
            catch (Exception) { return 0; }
        }

        // ------------------------------------------------------------------ drawing

        void BuildBackground()
        {
            _bgCache?.Dispose();
            _bgCache = new Bitmap(Math.Max(1, ClientSize.Width), Math.Max(1, ClientSize.Height));
            using (var g = Graphics.FromImage(_bgCache))
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.ScaleTransform(S, S);
                // Cover: the artificial sun stays in the upper right.
                float sc = Math.Max(W / _art.Width, H / _art.Height);
                float iw = _art.Width * sc, ih = _art.Height * sc;
                g.DrawImage(_art, (W - iw) * 0.7f, (H - ih) * 0.3f, iw, ih);
                using (var lb = new LinearGradientBrush(new RectangleF(0, 0, W, H), Color.Black, Color.Black, 0f))
                {
                    lb.InterpolationColors = new ColorBlend
                    {
                        Colors = new[] { Color.FromArgb(238, 7, 9, 12), Color.FromArgb(190, 7, 9, 12), Color.FromArgb(40, 7, 9, 12), Color.FromArgb(10, 7, 9, 12) },
                        Positions = new[] { 0f, 0.36f, 0.72f, 1f },
                    };
                    g.FillRectangle(lb, 0, 0, W, H);
                }
                using (var bb = new LinearGradientBrush(new RectangleF(0, H - 300, W, 300), Color.FromArgb(0, 7, 9, 12), Color.FromArgb(250, 7, 9, 12), 90f))
                    g.FillRectangle(bb, 0, H - 299, W, 300);
                using (var tb = new LinearGradientBrush(new RectangleF(0, 0, W, 110), Color.FromArgb(170, 5, 6, 8), Color.FromArgb(0, 5, 6, 8), 90f))
                    g.FillRectangle(tb, 0, 0, W, 109);
                using (var pen = new Pen(Color.FromArgb(40, 255, 255, 255)))
                    g.DrawRectangle(pen, 0, 0, W - 1 / S, H - 1 / S);
            }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            if (_bgCache == null || _bgCache.Width != ClientSize.Width || _bgCache.Height != ClientSize.Height) BuildBackground();
            g.DrawImageUnscaled(_bgCache, 0, 0);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.ScaleTransform(S, S);
            _hit.Clear();
            DrawTitleBar(g);
            DrawHero(g);
            DrawServers(g);
            DrawNews(g);
            DrawBottom(g);
            if (_overlay != Overlay.None) DrawOverlay(g);
        }

        bool Hot(string id) => _hover == id;

        void DrawTitleBar(Graphics g)
        {
            g.DrawImage(_icon, 18, 13, 22, 22);
            Ui.Draw(g, "SLEEP", _fHead, Color.FromArgb(200, Ui.Text), 50, 17, 2.2f);
            var close = new RectangleF(W - 50, 0, 50, 44);
            var min = new RectangleF(W - 100, 0, 50, 44);
            var gear = new RectangleF(W - 150, 0, 50, 44);
            _hit["close"] = close;
            _hit["min"] = min;
            _hit["settings"] = gear;
            if (Hot("close")) g.FillRectangle(new SolidBrush(Color.FromArgb(220, 196, 43, 28)), close);
            if (Hot("min")) g.FillRectangle(new SolidBrush(Color.FromArgb(30, 255, 255, 255)), min);
            if (Hot("settings") || _overlay == Overlay.Settings) g.FillRectangle(new SolidBrush(Color.FromArgb(30, 255, 255, 255)), gear);
            using (var pen = new Pen(Ui.Text, 1.4f))
            {
                float cx = close.X + 25, cy = 22;
                g.DrawLine(pen, cx - 6, cy - 6, cx + 6, cy + 6);
                g.DrawLine(pen, cx + 6, cy - 6, cx - 6, cy + 6);
                g.DrawLine(pen, min.X + 19, cy, min.X + 31, cy);
                DrawGear(g, pen, gear.X + 25, cy);
            }
            Ui.DrawRight(g, "Launcher " + Program.Version, _fSmall, Color.FromArgb(150, Ui.Dim), W - 166, 15);
        }

        static void DrawGear(Graphics g, Pen pen, float cx, float cy)
        {
            g.DrawEllipse(pen, cx - 5.5f, cy - 5.5f, 11, 11);
            g.DrawEllipse(pen, cx - 2, cy - 2, 4, 4);
            for (int i = 0; i < 8; i++)
            {
                double a = i * Math.PI / 4;
                g.DrawLine(pen, cx + (float)Math.Cos(a) * 5.5f, cy + (float)Math.Sin(a) * 5.5f, cx + (float)Math.Cos(a) * 8.5f, cy + (float)Math.Sin(a) * 8.5f);
            }
        }

        void DrawHero(Graphics g)
        {
            float x = M, y = 74;
            // Soft shadow behind the title so it reads over the night.
            Ui.Draw(g, "Sleep", _fTitle, Color.FromArgb(150, 0, 0, 0), x + 3, y + 4, 0);
            Ui.Draw(g, "Sleep", _fTitle, Ui.Text, x, y, 0);
            using (var lb = new LinearGradientBrush(new RectangleF(x + 6, y + 150, 200, 2), Ui.Danger, Color.FromArgb(0, Ui.Danger), 0f))
                g.FillRectangle(lb, x + 6, y + 150, 200, 2);
            Ui.Draw(g, "by Aljay Leodones", _fBy, Ui.Text, x + 6, y + 164);
            var tag = "AZAZ GAMES";
            float tw = Ui.Measure(g, tag, _fHead, 3.2f);
            var pill = new RectangleF(x + 6, y + 204, tw + 26, 28);
            Ui.Fill(g, pill, 14, Color.FromArgb(40, Ui.Accent));
            Ui.Stroke(g, pill, 14, Color.FromArgb(150, Ui.Accent));
            Ui.Draw(g, tag, _fHead, Ui.Accent, pill.X + 13, pill.Y + 6, 3.2f);
            Ui.Wrap(g, "First-person horror in a sealed-off town at night. Hold the mart with up to four friends, drag tables into the doorways and shoot the infected apart piece by piece. Hosting goes through the Sleep server: no VPN, no port forwarding.",
                _fBody, Ui.Dim, new RectangleF(x + 6, y + 248, 500, 90));
        }

        void DrawNews(Graphics g)
        {
            // (1.5.0) In the right column under the servers, down to just above the big button.
            var r = new RectangleF(W - M - 360, _serversBottom + 14, 360, 0);
            r.Height = H - 154 - 20 - r.Y;
            if (r.Height < 90) return;
            Ui.Fill(g, r, 10, Ui.Panel);
            Ui.Stroke(g, r, 10, Ui.Line);
            Ui.Draw(g, "WHAT'S NEW", _fHead, Ui.Accent, r.X + 20, r.Y + 16, 3);
            if (_remote != null)
            {
                var v = "VERSION " + _remote.Version;
                Ui.DrawRight(g, v, _fHead, Ui.Dim, r.Right - 20, r.Y + 16, 2);
            }
            float y = r.Y + 42;
            var notes = _remote?.Notes ?? new List<string> { _offline ? "Release notes appear here when the launcher is online." : "Loading the latest release…" };
            foreach (var n in notes)
            {
                float h = Ui.WrapHeight(g, n, _fBody, r.Width - 56);
                if (y + Math.Min(h, 21) > r.Bottom - 10) break;
                Ui.Fill(g, new RectangleF(r.X + 22, y + 7, 5, 5), 2.5f, Ui.Accent);
                var box = new RectangleF(r.X + 36, y, r.Width - 56, Math.Min(h + 1, r.Bottom - 12 - y));
                Ui.Wrap(g, n, _fBody, Ui.Text, box);
                y += box.Height + 6;
            }
        }

        void DrawServers(Graphics g)
        {
            float w = 360;
            var r = new RectangleF(W - M - w, 70, w, 0);
            int rows = Math.Min(_servers?.Count ?? 1, 6);
            r.Height = 58 + Math.Max(rows, 1) * 46;
            _serversBottom = r.Bottom;
            Ui.Fill(g, r, 10, Ui.Panel);
            Ui.Stroke(g, r, 10, Ui.Line);
            var dot = _serversUp == true ? Ui.Good : _serversUp == false ? Ui.Danger : Ui.Dim;
            float pulse = _serversUp == true ? (float)(0.5 + 0.5 * Math.Sin(_tick * 0.12)) : 0;
            Ui.Fill(g, new RectangleF(r.X + 20 - 4 * pulse, r.Y + 21 - 4 * pulse, 10 + 8 * pulse, 10 + 8 * pulse), 5 + 4 * pulse, Color.FromArgb((int)(70 * (1 - pulse)), dot));
            Ui.Fill(g, new RectangleF(r.X + 20, r.Y + 21, 10, 10), 5, dot);
            Ui.Draw(g, "PLAYING NOW", _fHead, Ui.Text, r.X + 40, r.Y + 18, 3);
            var right = _serversUp == true ? (_onlineCount + " in squads") : _serversUp == false ? "offline" : "…";
            Ui.DrawRight(g, right, _fSmall, Ui.Dim, r.Right - 20, r.Y + 18);
            float y = r.Y + 52;
            if (_servers == null || _servers.Count == 0)
            {
                Ui.Draw(g, _serversUp == false ? "The Sleep server can't be reached right now." : _serversUp == true ? "No squads out tonight. Host one in Multiplayer." : "Checking…", _fBody, Ui.Dim, r.X + 20, y + 4);
                return;
            }
            foreach (var s in _servers)
            {
                if (y + 40 > r.Bottom) break;
                Ui.Draw(g, Json.Str(s, "name"), _fBodyB, Ui.Text, r.X + 20, y);
                var mins = Json.Long(s, "minutes");
                Ui.Draw(g, "Version " + Json.Str(s, "version") + "  ·  open " + (mins < 1 ? "just now" : mins + " min"), _fSmall, Ui.Dim, r.X + 20, y + 20);
                Ui.DrawRight(g, (1 + Json.Long(s, "friends")) + " / 5", _fBodyB, Ui.Text, r.Right - 20, y);
                Ui.DrawRight(g, "squad", _fSmall, Ui.Accent2, r.Right - 20, y + 20);
                y += 46;
            }
        }

        void DrawBottom(Graphics g)
        {
            float barW = W - M * 2 - BtnW - 32;
            // Status
            Ui.Draw(g, _status, _fStatus, _statusColor, M, H - 150);
            var detail = _detail;
            double frac = -1;
            if (_mode == Mode.Working && _p != null)
            {
                frac = _p.Total > 0 ? Math.Min(1.0, _p.Done / (double)_p.Total) : 0;
                var parts = new List<string>();
                if (_p.Total > 0) parts.Add(string.Format("{0} of {1}", Updater.Size(_p.Done), Updater.Size(_p.Total)));
                if (_p.DownloadTotal > 0) parts.Add(string.Format("downloaded {0} of {1}", Updater.Size(_p.Downloaded), Updater.Size(_p.DownloadTotal)));
                if (_p.Speed > 1024 && _p.DownloadTotal > _p.Downloaded)
                {
                    parts.Add(Updater.Size((long)_p.Speed) + "/s");
                    var left = TimeSpan.FromSeconds((_p.DownloadTotal - _p.Downloaded) / Math.Max(_p.Speed, 1));
                    parts.Add(left.TotalMinutes >= 1 ? "about " + Math.Ceiling(left.TotalMinutes) + " min left" : "less than a minute left");
                }
                detail = (_p.Total > 0 ? Math.Floor(frac * 100) + "%  ·  " : "") + (parts.Count > 0 ? string.Join("  ·  ", parts) : _p.Phase);
            }
            Ui.Wrap(g, detail, _fBody, Ui.Dim, new RectangleF(M, H - 118, barW, 40));
            // Progress
            var track = new RectangleF(M, H - 72, barW, 6);
            Ui.Fill(g, track, 3, Color.FromArgb(34, 255, 255, 255));
            if (frac >= 0)
            {
                var fill = new RectangleF(track.X, track.Y, Math.Max(6, (float)(track.Width * frac)), track.Height);
                using (var lb = new LinearGradientBrush(new RectangleF(track.X, track.Y, track.Width, track.Height), Color.FromArgb(214, 120, 36), Ui.AccentHot, 0f))
                using (var p = Ui.Round(fill, 3))
                    g.FillPath(lb, p);
            }
            else if (_mode == Mode.Checking || _mode == Mode.Working)
            {
                float seg = barW * 0.22f, t = (_tick * 9) % (barW + seg) - seg;
                var fill = RectangleF.Intersect(new RectangleF(M + t, track.Y, seg, track.Height), track);
                if (fill.Width > 0) Ui.Fill(g, fill, 3, Color.FromArgb(200, Ui.Accent));
            }
            // Game folder and links (moving, verifying and uninstalling live in Settings)
            float y = H - 50, x = M;
            float rx = M + barW;
            float ww = Ui.Measure(g, "Website", _fSmall);
            Link(g, "website", "Website", rx - ww, y);
            rx -= ww + 16;
            float sw = Ui.Measure(g, "Settings", _fSmall);
            Link(g, "settings", "Settings", rx - sw, y);
            rx -= sw + 24;
            bool installed = _u.InstalledVersion(_remote) != "";
            if (installed || _mode == Mode.Working || _mode == Mode.Error)
            {
                x += Ui.Draw(g, "Game folder", _fSmall, Ui.Dim, x, y) + 10;
                var path = Ui.Ellipsize(g, _u.InstallDir, _fSmall, rx - x - 70);
                x += Ui.Draw(g, path, _fSmall, Ui.Text, x, y) + 14;
                if (Directory.Exists(_u.InstallDir)) Link(g, "folder", "Open", x, y);
            }
            else
                Ui.Draw(g, Ui.Ellipsize(g, "You choose where the game goes when you press INSTALL.", _fSmall, rx - x), _fSmall, Ui.Dim, x, y);
            // The button
            var b = new RectangleF(W - M - BtnW, H - 154, BtnW, BtnH);
            string label;
            bool enabled = true, primary = true;
            switch (_mode)
            {
                case Mode.Install: label = "INSTALL"; break;
                case Mode.Update: label = "UPDATE"; break;
                case Mode.Ready: label = "PLAY"; break;
                case Mode.Working when _moving: label = "MOVING"; primary = false; enabled = false; break;
                case Mode.Working: label = "PAUSE"; primary = false; break;
                case Mode.Error: label = _status == "Paused" ? "RESUME" : "RETRY"; break;
                case Mode.Playing: label = "PLAYING"; enabled = false; break;
                default: label = "PLEASE WAIT"; enabled = false; break;
            }
            if (enabled) _hit["main"] = b;
            bool hot = enabled && Hot("main"), down = enabled && _pressed == "main";
            if (primary)
            {
                if (enabled)
                {
                    // Glow
                    for (int i = 3; i >= 1; i--)
                        Ui.Fill(g, RectangleF.Inflate(b, i * 5, i * 5), 12 + i * 5, Color.FromArgb(hot ? 22 : 12, Ui.Accent));
                }
                var top = !enabled ? Color.FromArgb(70, 62, 50) : down ? Color.FromArgb(214, 136, 40) : hot ? Ui.AccentHot : Ui.Accent;
                var bot = !enabled ? Color.FromArgb(58, 52, 44) : down ? Color.FromArgb(190, 112, 30) : hot ? Color.FromArgb(245, 160, 64) : Color.FromArgb(222, 132, 38);
                using (var lb = new LinearGradientBrush(b, top, bot, 90f))
                using (var p = Ui.Round(b, 12))
                    g.FillPath(lb, p);
                var tc = enabled ? Color.FromArgb(26, 17, 6) : Color.FromArgb(150, Ui.Dim);
                Ui.Draw(g, label, _fBtn, tc, b.X + (b.Width - Ui.Measure(g, label, _fBtn, 4)) / 2, b.Y + 20, 4);
            }
            else
            {
                Ui.Fill(g, b, 12, hot ? Color.FromArgb(60, 255, 255, 255) : Color.FromArgb(34, 255, 255, 255));
                Ui.Stroke(g, b, 12, Color.FromArgb(90, 255, 255, 255));
                Ui.Draw(g, label, _fBtn, Ui.Text, b.X + (b.Width - Ui.Measure(g, label, _fBtn, 4)) / 2, b.Y + 20, 4);
            }
            Ui.DrawRight(g, "© Aljay Leodones · AzAz Games", _fSmall, Color.FromArgb(130, Ui.Dim), W - M, H - 50);
        }

        float Link(Graphics g, string id, string text, float x, float y, Color? color = null)
        {
            bool enabled = _mode != Mode.Working || id == "website" || id == "folder" || id == "settings";
            var c = !enabled ? Color.FromArgb(90, Ui.Dim) : Hot(id) ? Color.White : color ?? Ui.Accent2;
            float w = Ui.Draw(g, text, _fSmall, c, x, y);
            if (enabled) _hit[id] = new RectangleF(x - 2, y - 4, w + 4, 22);
            if (Hot(id) && enabled)
                using (var pen = new Pen(c, 1)) g.DrawLine(pen, x, y + 18, x + w, y + 18);
            return x + w;
        }

        // ------------------------------------------------------------------ panels

        void DrawOverlay(Graphics g)
        {
            // Only the panel (and the window's own buttons) take clicks while it is open.
            var keep = new[] { "close", "min" }.Where(_hit.ContainsKey).ToDictionary(k => k, k => _hit[k]);
            _hit.Clear();
            foreach (var kv in keep) _hit[kv.Key] = kv.Value;
            using (var b = new SolidBrush(Color.FromArgb(210, 6, 7, 9))) g.FillRectangle(b, 0, 44, W, H - 44);
            if (_overlay == Overlay.Settings) DrawSettings(g);
            else DrawPicker(g);
        }

        RectangleF PanelFrame(Graphics g, float w, float h, string title)
        {
            var r = new RectangleF((W - w) / 2, 44 + (H - 44 - h) / 2, w, h);
            for (int i = 3; i >= 1; i--) Ui.Fill(g, RectangleF.Inflate(r, i * 6, i * 6), 14 + i * 6, Color.FromArgb(14, 0, 0, 0));
            Ui.Fill(g, r, 14, Color.FromArgb(250, 15, 18, 23));
            Ui.Stroke(g, r, 14, Color.FromArgb(40, 255, 255, 255));
            using (var lb = new LinearGradientBrush(new RectangleF(r.X + 32, r.Y, 200, 3), Ui.Accent, Color.FromArgb(0, Ui.Accent), 0f))
                g.FillRectangle(lb, r.X + 32, r.Y, 200, 3);
            Ui.Draw(g, title, _fPanel, Ui.Text, r.X + 32, r.Y + 26, 2);
            var x = new RectangleF(r.Right - 60, r.Y + 22, 40, 40);
            _hit["ov_close"] = x;
            if (Hot("ov_close")) Ui.Fill(g, x, 8, Color.FromArgb(30, 255, 255, 255));
            using (var pen = new Pen(Ui.Text, 1.4f))
            {
                float cx = x.X + 20, cy = x.Y + 20;
                g.DrawLine(pen, cx - 6, cy - 6, cx + 6, cy + 6);
                g.DrawLine(pen, cx + 6, cy - 6, cx - 6, cy + 6);
            }
            return r;
        }

        /// <summary>Where to install (or move) the game: drives, Browse, the resulting folder, space and the go button.</summary>
        void DrawPicker(Graphics g)
        {
            bool move = _overlay == Overlay.Move;
            var r = PanelFrame(g, 720, 470, move ? "MOVE THE GAME" : "INSTALL SLEEP");
            float x = r.X + 32, y = r.Y + 80, w = r.Width - 64;
            Ui.Wrap(g, "Pick a drive or any folder. The game always goes in its own \"AzAz Games\\Sleep\" folder there, so it never mixes with your other files.",
                _fBody, Ui.Dim, new RectangleF(x, y, w, 44));
            y += 62;
            Ui.Draw(g, "DRIVE", _fHead, Ui.Dim, x, y, 2.5f);
            y += 24;
            float cx = x;
            var pickRoot = _pickDir != null ? Path.GetPathRoot(_pickDir) : "";
            foreach (var d in _drives)
            {
                string label;
                try { label = d.Name.TrimEnd('\\') + "   " + Updater.Size(d.AvailableFreeSpace) + " free"; }
                catch (Exception) { continue; }
                float cw = Ui.Measure(g, label, _fSmall) + 32;
                var chip = new RectangleF(cx, y, cw, 36);
                if (cx + cw > r.Right - 32) break;
                bool on = string.Equals(pickRoot, d.Name, StringComparison.OrdinalIgnoreCase);
                var id = "drive:" + d.Name;
                _hit[id] = chip;
                Ui.Fill(g, chip, 8, on ? Color.FromArgb(46, Ui.Accent) : Hot(id) ? Color.FromArgb(40, 255, 255, 255) : Color.FromArgb(20, 255, 255, 255));
                Ui.Stroke(g, chip, 8, on ? Ui.Accent : Color.FromArgb(60, 255, 255, 255), on ? 1.5f : 1f);
                Ui.Draw(g, label, _fSmall, on ? Ui.Text : Ui.Dim, chip.X + 16, chip.Y + 9);
                cx += cw + 10;
            }
            y += 56;
            Ui.Draw(g, move ? "NEW GAME FOLDER" : "GAME FOLDER", _fHead, Ui.Dim, x, y, 2.5f);
            y += 24;
            var field = new RectangleF(x, y, w - 150, 46);
            _hit["field"] = field;
            Ui.Fill(g, field, 8, Color.FromArgb(Hot("field") ? 60 : 44, 0, 0, 0));
            Ui.Stroke(g, field, 8, _pickProblem != null && !_pickSoft ? Color.FromArgb(160, Ui.Danger) : Color.FromArgb(70, 255, 255, 255));
            Ui.Draw(g, Ui.Ellipsize(g, _pickDir ?? "", _fBodyB, field.Width - 32), _fBodyB, Ui.Text, field.X + 16, field.Y + 13);
            Button(g, "browse", new RectangleF(field.Right + 12, y, 138, 46), "BROWSE…", 1, true);
            y += 60;
            // Space, then whether it can go there.
            var root = pickRoot.TrimEnd('\\');
            var info = new List<string>();
            if (_pickNeed > 0) info.Add((move ? "Game size " : "Needs ") + Updater.Size(_pickNeed));
            if (!move && _remote != null) info.Add(Updater.Size(_remote.DownloadSize) + " download");
            if (_pickFree >= 0) info.Add(Updater.Size(_pickFree) + " free on " + root);
            Ui.Draw(g, string.Join("  ·  ", info), _fSmall, Ui.Dim, x, y);
            y += 24;
            if (_pickProblem != null) Ui.Wrap(g, _pickProblem, _fSmall, _pickSoft ? Ui.Accent : Ui.Danger, new RectangleF(x, y, w, 40));
            else Ui.Draw(g, move ? "Ready to move here." : "Ready to install here.", _fSmall, Ui.Good, x, y);
            // Buttons
            float by = r.Bottom - 32 - 52;
            if (!move) Check(g, "shortcut", x, by + 15, "Create a desktop shortcut", _pickShortcut);
            var ok = new RectangleF(r.Right - 32 - 200, by, 200, 52);
            Button(g, "ov_ok", ok, move ? "MOVE" : "INSTALL", 0, _pickProblem == null);
            Button(g, "ov_cancel", new RectangleF(ok.X - 12 - 140, by, 140, 52), move ? "BACK" : "CANCEL", 1, true);
        }

        void DrawSettings(Graphics g)
        {
            var r = PanelFrame(g, 720, 470, "SETTINGS");
            float x = r.X + 32, y = r.Y + 84, w = r.Width - 64;
            bool installed = _u.InstalledVersion(_remote) != "";
            bool free = !Busy;
            Ui.Draw(g, "GAME FOLDER", _fHead, Ui.Dim, x, y, 2.5f);
            y += 24;
            Ui.Draw(g, Ui.Ellipsize(g, _u.InstallDir, _fBodyB, w), _fBodyB, Ui.Text, x, y);
            y += 26;
            string line;
            if (installed)
            {
                line = "Version " + _u.InstalledVersion(_remote);
                try { line += "  ·  " + Updater.Size(new DriveInfo(Path.GetPathRoot(_u.InstallDir)).AvailableFreeSpace) + " free on " + Path.GetPathRoot(_u.InstallDir).TrimEnd('\\'); }
                catch (Exception) { }
            }
            else line = "Not installed yet. INSTALL lets you pick the drive and folder.";
            Ui.Draw(g, line, _fSmall, Ui.Dim, x, y);
            y += 32;
            float bx = x;
            bx += Button(g, "folder", new RectangleF(bx, y, 170, 44), "OPEN FOLDER", 1, Directory.Exists(_u.InstallDir)) + 12;
            bx += Button(g, "s_move", new RectangleF(bx, y, 170, 44), "MOVE…", 1, installed && free) + 12;
            Button(g, "s_verify", new RectangleF(bx, y, 190, 44), "VERIFY FILES", 1, installed && free);
            y += 66;
            using (var pen = new Pen(Color.FromArgb(26, 255, 255, 255))) g.DrawLine(pen, x, y, x + w, y);
            y += 22;
            Check(g, "s_shortcut", x, y, "Desktop shortcut", Setup.DesktopShortcutWanted);
            y += 34;
            Ui.Wrap(g, "Verify files checks every game file against the release and downloads only what is damaged or missing.",
                _fSmall, Ui.Dim, new RectangleF(x, y, w, 40));
            float by = r.Bottom - 32 - 44;
            Button(g, "s_uninstall", new RectangleF(x, by, 170, 44), "UNINSTALL", 2, installed && free);
            Ui.DrawRight(g, "Launcher " + Program.Version + "  ·  © Aljay Leodones · AzAz Games", _fSmall, Color.FromArgb(150, Ui.Dim), r.Right - 32, by + 14);
        }

        /// <summary>A panel button: style 0 primary (amber), 1 secondary, 2 danger outline. Returns its width.</summary>
        float Button(Graphics g, string id, RectangleF b, string label, int style, bool enabled)
        {
            if (enabled) _hit[id] = b;
            bool hot = enabled && Hot(id), down = enabled && _pressed == id;
            Color tc;
            if (style == 0)
            {
                var top = !enabled ? Color.FromArgb(70, 62, 50) : down ? Color.FromArgb(214, 136, 40) : hot ? Ui.AccentHot : Ui.Accent;
                var bot = !enabled ? Color.FromArgb(58, 52, 44) : down ? Color.FromArgb(190, 112, 30) : hot ? Color.FromArgb(245, 160, 64) : Color.FromArgb(222, 132, 38);
                using (var lb = new LinearGradientBrush(b, top, bot, 90f))
                using (var p = Ui.Round(b, 10))
                    g.FillPath(lb, p);
                tc = enabled ? Color.FromArgb(26, 17, 6) : Color.FromArgb(150, Ui.Dim);
            }
            else
            {
                var edge = style == 2 ? Ui.Danger : Color.White;
                Ui.Fill(g, b, 10, Color.FromArgb(!enabled ? 10 : down ? 70 : hot ? 50 : 24, edge));
                Ui.Stroke(g, b, 10, Color.FromArgb(enabled ? (hot ? 160 : 90) : 30, edge));
                tc = !enabled ? Color.FromArgb(90, Ui.Dim) : style == 2 ? Ui.Danger : Ui.Text;
            }
            Ui.Draw(g, label, _fBtnS, tc, b.X + (b.Width - Ui.Measure(g, label, _fBtnS, 2)) / 2, b.Y + (b.Height - _fBtnS.Size * 1.2f) / 2, 2);
            return b.Width;
        }

        void Check(Graphics g, string id, float x, float y, string label, bool on)
        {
            var box = new RectangleF(x, y, 22, 22);
            Ui.Fill(g, box, 5, on ? Ui.Accent : Color.FromArgb(Hot(id) ? 50 : 26, 255, 255, 255));
            Ui.Stroke(g, box, 5, on ? Ui.Accent : Color.FromArgb(120, 255, 255, 255));
            if (on)
                using (var pen = new Pen(Color.FromArgb(26, 17, 6), 2.4f) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round })
                    g.DrawLines(pen, new[] { new PointF(x + 5.5f, y + 11.5f), new PointF(x + 9.5f, y + 15.5f), new PointF(x + 16.5f, y + 7) });
            float w = Ui.Draw(g, label, _fBody, Hot(id) ? Color.White : Ui.Text, x + 34, y + 2);
            _hit[id] = new RectangleF(x - 4, y - 4, w + 46, 30);
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (_moving)
            {
                MessageBox.Show(this, "The game is being moved. Wait until it finishes, then close the launcher.", "Sleep",
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                e.Cancel = true;
                return;
            }
            if (_mode == Mode.Working)
            {
                var r = MessageBox.Show(this, "Stop the download? It continues from where it stopped next time.", "Sleep",
                    MessageBoxButtons.OKCancel, MessageBoxIcon.Question);
                if (r != DialogResult.OK) { e.Cancel = true; return; }
                _cts?.Cancel();
            }
            base.OnFormClosing(e);
        }
    }
}
