using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Principal;

public sealed class ChildSession {
    public int Id; public int State; public string Sid; public string Name;
    public bool Admin;
}
public static class FamilyNative {
    [StructLayout(LayoutKind.Sequential)] struct SidAttributes { public IntPtr Sid; public uint Attributes; }
    [StructLayout(LayoutKind.Sequential)] struct TokenGroups { public uint Count; public SidAttributes First; }
    [DllImport("advapi32.dll", SetLastError=true)] static extern bool GetTokenInformation(IntPtr token,int kind,IntPtr data,int length,out int needed);
    [StructLayout(LayoutKind.Sequential)] struct Session { public int Id; public IntPtr Station; public int State; }
    [DllImport("wtsapi32.dll", SetLastError=true)] static extern bool WTSEnumerateSessions(IntPtr server,int reserved,int version,out IntPtr data,out int count);
    [DllImport("wtsapi32.dll")] static extern void WTSFreeMemory(IntPtr data);
    [DllImport("wtsapi32.dll", SetLastError=true)] static extern bool WTSQueryUserToken(int session,out IntPtr token);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    [DllImport("wtsapi32.dll", SetLastError=true)] static extern bool WTSLogoffSession(IntPtr server,int session,bool wait);
    [DllImport("wtsapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool WTSSendMessageW(IntPtr server,int session,string title,int titleBytes,string message,int messageBytes,int style,int timeout,out int response,bool wait);
    public static ChildSession[] Sessions() {
        IntPtr data; int count;
        if(!WTSEnumerateSessions(IntPtr.Zero,0,1,out data,out count)) throw new Win32Exception();
        var result=new List<ChildSession>();
        try {
            int size=Marshal.SizeOf(typeof(Session));
            for(int i=0;i<count;i++) {
                var s=(Session)Marshal.PtrToStructure(IntPtr.Add(data,i*size),typeof(Session));
                if(s.Id==0 || (s.State!=0 && s.State!=4)) continue;
                IntPtr token;
                if(!WTSQueryUserToken(s.Id,out token)) {
                    int error=Marshal.GetLastWin32Error();
                    // A session can disappear between enumeration and token query.
                    if(error==1008 || error==7022) continue;
                    throw new Win32Exception(error,"Impossible de classifier la session " + s.Id);
                }
                try {
                    using(var identity=new WindowsIdentity(token)) {
                        // Read raw token groups: WindowsIdentity.Groups omits deny-only
                        // administrator membership in filtered UAC tokens.
                        bool admin=IsAdministratorToken(token);
                        result.Add(new ChildSession {Id=s.Id,State=s.State,Sid=identity.User.Value,Name=identity.Name,Admin=admin});
                    }
                } finally {CloseHandle(token);}
            }
        } finally {WTSFreeMemory(data);}
        return result.ToArray();
    }
    public static bool ContainsAdministratorGroup(IntPtr data) {
        int count=Marshal.ReadInt32(data);
        int offset=Marshal.OffsetOf(typeof(TokenGroups),"First").ToInt32();
        int stride=Marshal.SizeOf(typeof(SidAttributes));
        for(int i=0;i<count;i++) {
            var group=(SidAttributes)Marshal.PtrToStructure(IntPtr.Add(data,offset+i*stride),typeof(SidAttributes));
            if(new SecurityIdentifier(group.Sid).Value=="S-1-5-32-544") return true;
        }
        return false;
    }
    public static bool IsAdministratorToken(IntPtr token) {
        int needed;
        GetTokenInformation(token,2,IntPtr.Zero,0,out needed);
        if(needed<=0) throw new Win32Exception();
        IntPtr data=Marshal.AllocHGlobal(needed);
        try {
            if(!GetTokenInformation(token,2,data,needed,out needed)) throw new Win32Exception();
            return ContainsAdministratorGroup(data);
        } finally {Marshal.FreeHGlobal(data);}
    }
    public static void Logoff(int session) {
        if(!WTSLogoffSession(IntPtr.Zero,session,false)) throw new Win32Exception();
    }
    public static void Warn(int session,string message) {
        int response; string title="Temps enfants";
        if(!WTSSendMessageW(IntPtr.Zero,session,title,title.Length*2,message,message.Length*2,0x40,30,out response,false)) throw new Win32Exception();
    }
}
