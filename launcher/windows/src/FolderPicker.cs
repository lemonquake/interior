using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Sleep.Launcher
{
    /// <summary>
    /// The Explorer-style "Select folder" dialog (IFileOpenDialog with FOS_PICKFOLDERS) instead of WinForms' old tree
    /// dialog; falls back to FolderBrowserDialog if the shell dialog can't be created.
    /// </summary>
    static class FolderPicker
    {
        const uint FOS_PICKFOLDERS = 0x20, FOS_FORCEFILESYSTEM = 0x40, FOS_PATHMUSTEXIST = 0x800;
        const uint SIGDN_FILESYSPATH = 0x80058000;
        const int ERROR_CANCELLED = unchecked((int)0x800704C7);

        /// <summary>The chosen folder, or null when the player cancels.</summary>
        public static string Pick(IWin32Window owner, string title, string start)
        {
            try
            {
                var dlg = (IFileOpenDialog)new FileOpenDialogRCW();
                try
                {
                    dlg.GetOptions(out var o);
                    dlg.SetOptions(o | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST);
                    dlg.SetTitle(title);
                    dlg.SetOkButtonLabel("Select");
                    if (!string.IsNullOrEmpty(start))
                    {
                        try
                        {
                            SHCreateItemFromParsingName(start, IntPtr.Zero, typeof(IShellItem).GUID, out var item);
                            dlg.SetFolder(item);
                        }
                        catch (Exception) { }
                    }
                    int hr = dlg.Show(owner?.Handle ?? IntPtr.Zero);
                    if (hr == ERROR_CANCELLED) return null;
                    if (hr != 0) Marshal.ThrowExceptionForHR(hr);
                    dlg.GetResult(out var result);
                    result.GetDisplayName(SIGDN_FILESYSPATH, out var path);
                    return path;
                }
                finally { Marshal.FinalReleaseComObject(dlg); }
            }
            catch (COMException)
            {
                using (var f = new FolderBrowserDialog { Description = title, ShowNewFolderButton = true, SelectedPath = start ?? "" })
                    return f.ShowDialog(owner) == DialogResult.OK ? f.SelectedPath : null;
            }
        }

        [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
        static extern void SHCreateItemFromParsingName(string path, IntPtr pbc, [In, MarshalAs(UnmanagedType.LPStruct)] Guid riid, out IShellItem item);

        [ComImport, Guid("DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7")]
        class FileOpenDialogRCW { }

        // IModalWindow, IFileDialog and IFileOpenDialog methods in vtable order.
        [ComImport, Guid("d57c7288-d4ad-4768-be02-9d969532d960"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        interface IFileOpenDialog
        {
            [PreserveSig] int Show(IntPtr parent);
            void SetFileTypes(uint count, IntPtr specs);
            void SetFileTypeIndex(uint index);
            void GetFileTypeIndex(out uint index);
            void Advise(IntPtr sink, out uint cookie);
            void Unadvise(uint cookie);
            void SetOptions(uint fos);
            void GetOptions(out uint fos);
            void SetDefaultFolder(IShellItem item);
            void SetFolder(IShellItem item);
            void GetFolder(out IShellItem item);
            void GetCurrentSelection(out IShellItem item);
            void SetFileName([MarshalAs(UnmanagedType.LPWStr)] string name);
            void GetFileName([MarshalAs(UnmanagedType.LPWStr)] out string name);
            void SetTitle([MarshalAs(UnmanagedType.LPWStr)] string title);
            void SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string text);
            void SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string label);
            void GetResult(out IShellItem item);
            void AddPlace(IShellItem item, int place);
            void SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string ext);
            void Close(int hr);
            void SetClientGuid(ref Guid guid);
            void ClearClientData();
            void SetFilter(IntPtr filter);
            void GetResults(out IntPtr items);
            void GetSelectedItems(out IntPtr items);
        }

        [ComImport, Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        interface IShellItem
        {
            void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
            void GetParent(out IShellItem item);
            void GetDisplayName(uint sigdn, [MarshalAs(UnmanagedType.LPWStr)] out string name);
            void GetAttributes(uint mask, out uint attrs);
            void Compare(IShellItem item, uint hint, out int order);
        }
    }
}
