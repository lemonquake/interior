using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

namespace Sleep.Launcher
{
    static class Program
    {
        public const string BaseUrl = "https://sleep.15-235-246-87.sslip.io";
        public const string Website = BaseUrl + "/";
        public static readonly string Version = Assembly.GetExecutingAssembly().GetName().Version.ToString(3);
        public const string Studio = "AzAz Games", GameFolder = "Sleep";
        // The launcher and its settings; the game goes wherever the player chooses (InstallDir). --data-dir is for tests.
        public static string Root => Args.TryGetValue("data-dir", out var d) ? Path.GetFullPath(d) :
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Sleep");
        public static string InstalledLauncher => Path.Combine(Root, "SleepLauncher.exe");
        public static string SelfPath => Process.GetCurrentProcess().MainModule.FileName;
        public static Dictionary<string, string> Args = new Dictionary<string, string>();

        [STAThread]
        static int Main(string[] argv)
        {
            foreach (var a in argv)
            {
                if (!a.StartsWith("--")) continue;
                var i = a.IndexOf('=');
                Args[i > 0 ? a.Substring(2, i - 2) : a.Substring(2)] = i > 0 ? a.Substring(i + 1) : "true";
            }
            var baseUrl = Arg("base-url", BaseUrl);
            if (Args.ContainsKey("selftest")) return SelfTest(baseUrl);
            if (Args.ContainsKey("uninstall")) return Setup.Uninstall();
            CleanupOld();
            using (var single = new Mutex(true, @"Local\SleepGameLauncher", out bool first))
            {
                if (!first)
                {
                    var h = Native.FindWindow(null, LauncherForm.WindowTitle);
                    if (h != IntPtr.Zero) { Native.ShowWindow(h, 9); Native.SetForegroundWindow(h); }
                    return 0;
                }
                if (!Args.ContainsKey("portable") && Setup.InstallSelfAndRelaunch(argv)) return 0;
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new LauncherForm(baseUrl));
            }
            return 0;
        }

        public static string Arg(string k, string def) => Args.TryGetValue(k, out var v) ? v : def;

        static void CleanupOld()
        {
            try { var old = SelfPath + ".old"; if (File.Exists(old)) File.Delete(old); } catch (Exception) { }
        }

        public static string Settings => Path.Combine(Root, "launcher-settings.json");

        static Dictionary<string, object> ReadSettings()
        {
            try { if (File.Exists(Settings)) return Json.Obj(Json.Parse(File.ReadAllText(Settings))); }
            catch (Exception) { }
            return new Dictionary<string, object>();
        }

        /// <summary>
        /// (1.5.0) The game always lives in "AzAz Games\Sleep" inside the place the player picks: D:\ gives
        /// D:\AzAz Games\Sleep, and picking either of those folders themselves keeps them as they are.
        /// </summary>
        public static string GameFolderIn(string place)
        {
            var p = Path.GetFullPath(place.Trim()).TrimEnd('\\');
            if (p.EndsWith("\\" + Studio + "\\" + GameFolder, StringComparison.OrdinalIgnoreCase)) return p;
            if (Path.GetFileName(p).Equals(Studio, StringComparison.OrdinalIgnoreCase)) return Path.Combine(p, GameFolder);
            return Path.Combine(p + "\\", Studio, GameFolder);
        }

        /// <summary>C:\AzAz Games\Sleep (the Windows drive), like other studios' game folders.</summary>
        public static string DefaultInstallDir => GameFolderIn(Path.GetPathRoot(Environment.GetFolderPath(Environment.SpecialFolder.Windows)) ?? "C:\\");

        public static string InstallDir
        {
            get
            {
                var dir = Json.Str(ReadSettings(), "install_dir");
                if (dir != "") return dir;
                // Launchers before 1.5.0 installed into the launcher's own folder without always saving it.
                var legacy = Path.Combine(Root, "Game");
                if (File.Exists(Path.Combine(legacy, ".launcher", "state.json"))) return legacy;
                return DefaultInstallDir;
            }
            set
            {
                var d = ReadSettings();
                d["install_dir"] = value;
                Directory.CreateDirectory(Root);
                File.WriteAllText(Settings, Json.Write(d));
            }
        }

        /// <summary>
        /// --selftest --install-dir=X [--report=file] [--base-url=U]: installs or updates without a window and writes a JSON
        /// report (tests and CI; nothing is launched).
        /// </summary>
        static int SelfTest(string baseUrl)
        {
            Native.AttachConsole(-1);
            var report = new Dictionary<string, object> { ["launcher"] = Version, ["ok"] = false };
            var sw = Stopwatch.StartNew();
            try
            {
                var dir = Arg("install-dir", Path.Combine(Path.GetTempPath(), "sleep-selftest"));
                if (Args.ContainsKey("game-folder")) dir = GameFolderIn(dir);  // the folder rule the window uses
                report["install_dir"] = dir;
                report["default_install_dir"] = DefaultInstallDir;
                var u = new Updater(baseUrl, dir);
                UpdateProgress last = null;
                u.Progress += p => last = p;
                var m = u.FetchAsync(CancellationToken.None).GetAwaiter().GetResult();
                report["version"] = m.Version;
                report["before"] = u.InstalledVersion(m);
                report["pending_download"] = u.PendingDownload(m, false);
                u.ApplyAsync(m, Args.ContainsKey("verify"), CancellationToken.None).GetAwaiter().GetResult();
                report["after"] = u.InstalledVersion(m);
                report["downloaded"] = last?.Downloaded ?? 0;
                report["reused"] = last?.Reused ?? 0;
                report["written"] = last?.Done ?? 0;
                report["game_exe"] = File.Exists(u.GameExe(m));
                report["ok"] = (string)report["after"] == m.Version && (bool)report["game_exe"];
            }
            catch (Exception e)
            {
                report["error"] = e.GetType().Name + ": " + e.Message;
            }
            report["seconds"] = Math.Round(sw.Elapsed.TotalSeconds, 1);
            var text = Json.Write(report);
            Console.WriteLine(text);
            if (Args.TryGetValue("report", out var rp)) File.WriteAllText(rp, text);
            return (bool)report["ok"] ? 0 : 1;
        }
    }

    /// <summary>Per-user setup: the launcher lives in %LocalAppData%\Sleep with shortcuts and an Apps entry.</summary>
    static class Setup
    {
        const string UninstallKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\SleepGame";
        static string Desktop => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Sleep.lnk");
        static string StartMenu => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Sleep.lnk");

        /// <summary>First run from Downloads: copy the launcher into place, add shortcuts, start that copy. True if it did.</summary>
        public static bool InstallSelfAndRelaunch(string[] argv)
        {
            var self = Program.SelfPath;
            var target = Program.InstalledLauncher;
            try
            {
                if (string.Equals(Path.GetFullPath(self), Path.GetFullPath(target), StringComparison.OrdinalIgnoreCase))
                {
                    EnsureShortcuts(target);
                    return false;
                }
                Directory.CreateDirectory(Program.Root);
                bool newer = !File.Exists(target) ||
                    new Version(FileVersionInfo.GetVersionInfo(target).FileVersion ?? "0.0.0") <= new Version(FileVersionInfo.GetVersionInfo(self).FileVersion ?? "0.0.0");
                if (newer)
                {
                    if (IsRunning(target)) return false;
                    File.Copy(self, target, true);
                }
                EnsureShortcuts(target);
                Process.Start(new ProcessStartInfo(target, string.Join(" ", argv)) { UseShellExecute = false });
                return true;
            }
            catch (Exception)
            {
                return false;  // run from where it is
            }
        }

        static bool IsRunning(string exe)
        {
            foreach (var p in Process.GetProcessesByName(Path.GetFileNameWithoutExtension(exe)))
            {
                try { if (p.Id != Process.GetCurrentProcess().Id && string.Equals(p.MainModule.FileName, exe, StringComparison.OrdinalIgnoreCase)) return true; }
                catch (Exception) { }
            }
            return false;
        }

        public static bool DesktopShortcutWanted => !File.Exists(Path.Combine(Program.Root, ".no-desktop-shortcut"));

        /// <summary>Adds or removes the desktop shortcut and remembers the choice for later launcher starts.</summary>
        public static void SetDesktopShortcut(bool on)
        {
            var marker = Path.Combine(Program.Root, ".no-desktop-shortcut");
            try
            {
                Directory.CreateDirectory(Program.Root);
                if (on)
                {
                    if (File.Exists(marker)) File.Delete(marker);
                    if (!Program.Args.ContainsKey("portable") && !File.Exists(Desktop)) MakeShortcut(Desktop, Program.InstalledLauncher);
                }
                else
                {
                    File.WriteAllText(marker, "");
                    if (!Program.Args.ContainsKey("portable") && File.Exists(Desktop)) File.Delete(Desktop);
                }
            }
            catch (Exception) { }
        }

        public static void EnsureShortcuts(string target)
        {
            if (Program.Args.ContainsKey("portable")) return;  // test and portable runs leave shortcuts and Apps alone
            try
            {
                if (!File.Exists(StartMenu)) MakeShortcut(StartMenu, target);
                if (!File.Exists(Desktop) && !File.Exists(Path.Combine(Program.Root, ".no-desktop-shortcut"))) MakeShortcut(Desktop, target);
                using (var k = Registry.CurrentUser.CreateSubKey(UninstallKey))
                {
                    k.SetValue("DisplayName", "Sleep");
                    k.SetValue("Publisher", "AzAz Games");
                    k.SetValue("DisplayIcon", target + ",0");
                    k.SetValue("DisplayVersion", Program.Version);
                    k.SetValue("InstallLocation", Program.Root);
                    k.SetValue("UninstallString", "\"" + target + "\" --uninstall");
                    k.SetValue("URLInfoAbout", Program.Website);
                    k.SetValue("NoModify", 1, RegistryValueKind.DWord);
                    k.SetValue("NoRepair", 1, RegistryValueKind.DWord);
                }
            }
            catch (Exception) { }
        }

        static void MakeShortcut(string path, string target)
        {
            var t = Type.GetTypeFromProgID("WScript.Shell");
            dynamic shell = Activator.CreateInstance(t);
            try
            {
                dynamic lnk = shell.CreateShortcut(path);
                lnk.TargetPath = target;
                lnk.WorkingDirectory = Path.GetDirectoryName(target);
                lnk.IconLocation = target + ",0";
                lnk.Description = "Sleep by Aljay Leodones · AzAz Games";
                lnk.Save();
                Marshal.FinalReleaseComObject(lnk);
            }
            finally { Marshal.FinalReleaseComObject(shell); }
        }

        public static int Uninstall()
        {
            var game = Program.InstallDir;
            var r = MessageBox.Show("Remove Sleep and its launcher from this PC?\n\nGame files: " + game +
                "\n\nYour profile, outfits and settings are kept (they live in your user folder).", "Uninstall Sleep",
                MessageBoxButtons.OKCancel, MessageBoxIcon.Question);
            if (r != DialogResult.OK) return 1;
            try { RemoveGame(game); }
            catch (Exception e) { MessageBox.Show("Some game files could not be removed (" + e.Message + "). Close the game and try again.", "Sleep"); return 1; }
            foreach (var p in new[] { Desktop, StartMenu }) try { File.Delete(p); } catch (Exception) { }
            try { Registry.CurrentUser.DeleteSubKeyTree(UninstallKey, false); } catch (Exception) { }
            if (Program.Args.ContainsKey("portable")) return 0;
            // The launcher cannot delete itself while it runs: a hidden shell removes the folder a moment later.
            Process.Start(new ProcessStartInfo("cmd.exe", "/c ping 127.0.0.1 -n 3 >nul & rmdir /s /q \"" + Program.Root + "\"")
            { CreateNoWindow = true, UseShellExecute = false, WindowStyle = ProcessWindowStyle.Hidden });
            return 0;
        }

        /// <summary>
        /// Whether this user can create files at dir: tried in the nearest folder that exists, with a probe folder that
        /// is removed again (C:\ allows it for standard users; Program Files and Windows do not).
        /// </summary>
        public static bool CanWrite(string dir)
        {
            try
            {
                var at = Path.GetFullPath(dir);
                while (!Directory.Exists(at)) { at = Path.GetDirectoryName(at); if (at == null) return false; }
                var probe = Path.Combine(at, ".sleep-probe-" + Guid.NewGuid().ToString("N").Substring(0, 8));
                Directory.CreateDirectory(probe);
                File.WriteAllText(Path.Combine(probe, "x"), "");
                Directory.Delete(probe, true);
                return true;
            }
            catch (Exception) { return false; }
        }

        /// <summary>The installed game files (from the launcher's state) and the state folder, relative to dir.</summary>
        static List<string> InstalledFiles(string dir)
        {
            var d = Json.Obj(Json.Parse(File.ReadAllText(Path.Combine(dir, ".launcher", "state.json"))));
            var list = Json.Obj(d["files"]).Keys.Where(k => !k.Contains("..") && !Path.IsPathRooted(k) && File.Exists(Path.Combine(dir, k))).ToList();
            foreach (var f in Directory.GetFiles(Path.Combine(dir, ".launcher"), "*", SearchOption.AllDirectories))
                list.Add(f.Substring(dir.Length + 1));
            return list;
        }

        /// <summary>
        /// Moves an installed game. On the same drive the folder is renamed; to another drive every installed file is
        /// copied (with progress), then the old ones are removed. A failed copy leaves the old install as it was.
        /// </summary>
        public static void MoveGame(string from, string dest, Action<UpdateProgress> report)
        {
            from = Path.GetFullPath(from).TrimEnd('\\');
            dest = Path.GetFullPath(dest).TrimEnd('\\');
            if (Directory.Exists(dest) && Directory.GetFileSystemEntries(dest).Length > 0)
                throw new IOException(dest + " is not empty.");
            if (Directory.Exists(dest)) Directory.Delete(dest);
            Directory.CreateDirectory(Path.GetDirectoryName(dest));
            if (string.Equals(Path.GetPathRoot(from), Path.GetPathRoot(dest), StringComparison.OrdinalIgnoreCase))
            {
                Directory.Move(from, dest);
                RemoveEmptyStudioFolder(from);
                return;
            }
            var files = InstalledFiles(from);
            var p = new UpdateProgress { Phase = "Copying", Total = files.Sum(f => new FileInfo(Path.Combine(from, f)).Length) };
            var buf = new byte[1 << 20];
            var clock = Stopwatch.StartNew();
            try
            {
                foreach (var rel in files)
                {
                    p.File = rel;
                    var src = Path.Combine(from, rel);
                    var to = Path.Combine(dest, rel);
                    Directory.CreateDirectory(Path.GetDirectoryName(to));
                    using (var i = File.OpenRead(src))
                    using (var o = File.Create(to))
                    {
                        int n;
                        while ((n = i.Read(buf, 0, buf.Length)) > 0)
                        {
                            o.Write(buf, 0, n);
                            p.Done += n;
                            if (clock.ElapsedMilliseconds > 100) { report(p); clock.Restart(); }
                        }
                    }
                    File.SetLastWriteTimeUtc(to, File.GetLastWriteTimeUtc(src));
                }
            }
            catch (Exception)
            {
                try { Directory.Delete(dest, true); RemoveEmptyStudioFolder(dest); } catch (Exception) { }
                throw;
            }
            report(p);
            RemoveGame(from);
        }

        /// <summary>Removes "AzAz Games" above a game folder once nothing else is in it.</summary>
        static void RemoveEmptyStudioFolder(string gameDir)
        {
            try
            {
                var parent = Path.GetDirectoryName(Path.GetFullPath(gameDir).TrimEnd('\\'));
                if (parent != null && Path.GetFileName(parent).Equals(Program.Studio, StringComparison.OrdinalIgnoreCase) &&
                    Directory.Exists(parent) && Directory.GetFileSystemEntries(parent).Length == 0)
                    Directory.Delete(parent);
            }
            catch (Exception) { }
        }

        /// <summary>Deletes only the files the launcher installed (listed in its state), then the folders they leave empty.</summary>
        static void RemoveGame(string dir)
        {
            var state = Path.Combine(dir, ".launcher", "state.json");
            if (!File.Exists(state)) return;
            var d = Json.Obj(Json.Parse(File.ReadAllText(state)));
            var folders = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var kv in Json.Obj(d["files"]))
            {
                if (kv.Key.Contains("..") || Path.IsPathRooted(kv.Key)) continue;
                var p = Path.Combine(dir, kv.Key);
                foreach (var extra in new[] { p, p + ".download" })
                    if (File.Exists(extra)) File.Delete(extra);
                for (var f = Path.GetDirectoryName(p); f != null && f.Length > dir.Length; f = Path.GetDirectoryName(f)) folders.Add(f);
            }
            Directory.Delete(Path.Combine(dir, ".launcher"), true);
            foreach (var f in folders.OrderByDescending(x => x.Length))
                try { if (Directory.Exists(f) && Directory.GetFileSystemEntries(f).Length == 0) Directory.Delete(f); } catch (Exception) { }
            try { if (Directory.GetFileSystemEntries(dir).Length == 0) Directory.Delete(dir); } catch (Exception) { }
            RemoveEmptyStudioFolder(dir);
        }
    }

    static class Native
    {
        [DllImport("kernel32.dll")] public static extern bool AttachConsole(int pid);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
        [DllImport("user32.dll")] public static extern bool ReleaseCapture();
        [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, IntPtr l);
        [DllImport("user32.dll")] public static extern bool FlashWindow(IntPtr h, bool invert);
        [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr h, int attr, ref int value, int size);
    }
}
