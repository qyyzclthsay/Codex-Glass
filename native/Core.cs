using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using D = System.Collections.Generic.Dictionary<string, object>;

namespace CodexGlass {
static class J {
    public static D Obj(params object[] pairs) { var d=new D(); for(int i=0;i<pairs.Length;i+=2) d[(string)pairs[i]]=pairs[i+1]; return d; }
    public static D Map(object v) { return v as D ?? new D(); }
    public static object Get(object v,string key) { object result; return Map(v).TryGetValue(key,out result)?result:null; }
    public static string Str(object v) { return v as string; }
    public static string S(object v,string key,string fallback="") { return Str(Get(v,key))??fallback; }
    public static double? Num(object v) { if(v is byte || v is int || v is long || v is float || v is double || v is decimal) { double n=Convert.ToDouble(v,CultureInfo.InvariantCulture); if(!double.IsNaN(n)&&!double.IsInfinity(n)) return n; } return null; }
    public static double N(object v,string key,double fallback=0) { return Num(Get(v,key))??fallback; }
    public static bool B(object v,string key,bool fallback=false) { var n=Get(v,key); return n is bool?(bool)n:fallback; }
    public static IEnumerable<object> Items(object v) { return v is IEnumerable && !(v is string) && !(v is IDictionary)?((IEnumerable)v).Cast<object>():Enumerable.Empty<object>(); }
    public static JavaScriptSerializer Serializer() { return new JavaScriptSerializer {MaxJsonLength=4*1024*1024,RecursionLimit=64}; }
    public static object Parse(string s) { return Serializer().DeserializeObject(s); }
    public static string Json(object o) { return Serializer().Serialize(o); }
    public static double Now {get{return (DateTime.UtcNow-new DateTime(1970,1,1)).TotalMilliseconds;}}
    public static DateTime Time(double n) { return new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddMilliseconds(n).ToLocalTime(); }
    public static bool Date(string s) { DateTime d; return s!=null&&Regex.IsMatch(s,@"^\d{4}-\d{2}-\d{2}$")&&DateTime.TryParseExact(s,"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out d); }
    public static double Clamp(double n,double lo,double hi) { return Math.Max(lo,Math.Min(hi,n)); }
}
static class Model {
    public static string Identity(object account,object limits=null) {
        object raw=J.Get(limits,"accountId")??J.Get(account,"accountId")??J.Get(account,"id")??J.Get(account,"email");
        if(raw==null||Convert.ToString(raw)=="")return null;
        using(var hash=SHA256.Create()) return BitConverter.ToString(hash.ComputeHash(Encoding.UTF8.GetBytes(Convert.ToString(raw)))).Replace("-","").ToLowerInvariant();
    }
    public static D Normalize(object account,object result,double now) {
        object raw=J.Get(result,"rateLimitsByLimitId");
        var groups=raw==null?J.Obj("codex",J.Get(result,"rateLimits")):J.Map(raw);
        var windows=new List<object>(); string plan=J.Str(J.Get(account,"planType"));
        foreach(var pair in groups.OrderBy(p=>p.Key=="codex"?"":p.Key,StringComparer.Ordinal)) {
            var group=pair.Value; if(plan==null)plan=J.Str(J.Get(group,"planType"));
            foreach(string slot in new[]{"primary","secondary"}) {
                object w=J.Get(group,slot); double? used=J.Num(J.Get(w,"usedPercent")); if(!used.HasValue)continue;
                var reset=J.Num(J.Get(w,"resetsAt"));
                windows.Add(J.Obj("id",pair.Key+":"+slot,"group",pair.Key,"scope",J.Get(group,"limitName")??(pair.Key=="codex"?null:pair.Key),"model",J.Str(J.Get(group,"normalModelSlug")),"minutes",J.Num(J.Get(w,"windowDurationMins")),"used",used.Value,"remaining",J.Clamp(100-used.Value,0,100),"resetsAt",reset.HasValue?(object)(reset.Value*1000):null,"groupBlocked",J.B(group,"spendControlReached")||J.Get(group,"rateLimitReachedType")!=null));
            }
        }
        var credits=J.Get(result,"rateLimitResetCredits"); var count=J.Num(J.Get(credits,"availableCount"));
        var dates=J.Items(J.Get(credits,"credits")).Where(c=>J.S(c,"status")=="available"&&J.Num(J.Get(c,"expiresAt")).HasValue).Select(c=>J.N(c,"expiresAt")*1000).Where(n=>n>now).ToArray();
        return J.Obj("identity",Identity(account,result),"plan",plan,"windows",windows,"resets",J.Obj("count",count.HasValue?(object)Math.Max(0,Math.Floor(count.Value)):null,"expiresAt",dates.Length>0?(object)dates.Min():null),"allowed",J.Get(result,"ordinaryUsageAllowed") is bool?J.Get(result,"ordinaryUsageAllowed"):null,"observedAt",now);
    }
    public static D Cache(object snapshot,string id,double now) {
        if(id==null||J.S(snapshot,"identity")!=id||!J.Num(J.Get(snapshot,"observedAt")).HasValue||now-J.N(snapshot,"observedAt")>86400000||J.N(snapshot,"observedAt")>now+60000)return null;
        var windows=J.Items(J.Get(snapshot,"windows")).Where(w=>J.Num(J.Get(w,"remaining")).HasValue&&(J.Get(w,"resetsAt")==null||J.N(w,"resetsAt")>now)).ToList();
        if(windows.Count==0)return null;
        var result=new D(J.Map(snapshot));result["windows"]=windows;result["resets"]=J.Obj("count",null,"expiresAt",null);return result;
    }
    public static D Selected(object snapshot,string choice,double now) {
        var list=J.Items(J.Get(snapshot,"windows")).Where(w=>J.S(w,"group")=="codex"&&J.Num(J.Get(w,"remaining")).HasValue&&(J.Get(w,"resetsAt")==null||J.N(w,"resetsAt")>now)).ToList();
        var selected=choice=="week"?list.FirstOrDefault(w=>J.N(w,"minutes")==10080):choice=="five"?list.FirstOrDefault(w=>J.N(w,"minutes")==300):null;
        return selected==null?list.OrderBy(w=>J.N(w,"remaining")).Select(J.Map).FirstOrDefault():J.Map(selected);
    }
    public static string Plan(object raw) { string s=J.Str(raw); if(s==null)return "—"; var names=J.Obj("free","Free","go","Go","plus","Plus","pro","Pro","prolite","Pro","team","Team","business","Business","enterprise","Enterprise","edu","Edu");return J.S(names,s.ToLowerInvariant(),s); }
    public static D Usage(object raw,double now) {
        if(!(raw is D))throw new Exception("invalidReply");
        var days=new SortedDictionary<string,double>(StringComparer.Ordinal);var conflicts=new HashSet<string>();bool incomplete=false;object rows=J.Get(raw,"dailyUsageBuckets");
        foreach(var row in J.Items(rows)) {
            string date=J.S(row,"startDate"); double? n=J.Num(J.Get(row,"tokens"));
            if(!J.Date(date)||!n.HasValue||n.Value<0||n.Value>9007199254740991||Math.Floor(n.Value)!=n.Value){incomplete=true;continue;}
            if(days.ContainsKey(date)&&days[date]!=n.Value){conflicts.Add(date);incomplete=true;} days[date]=n.Value;
        }
        foreach(var date in conflicts)days.Remove(date);
        return J.Obj("days",rows is IEnumerable && !(rows is string) && !(rows is IDictionary)?days.Select(p=>(object)J.Obj("date",p.Key,"tokens",p.Value)).ToList():null,"observedAt",now,"incomplete",incomplete);
    }
    public static List<D> Series(object usage,int range,DateTime today) {
        var records=J.Items(J.Get(usage,"days")).ToDictionary(d=>J.S(d,"date"),d=>J.Get(d,"tokens")); var result=new List<D>();
        for(int i=range-1;i>=0;i--){string date=today.AddDays(-i).ToString("yyyy-MM-dd");object n;records.TryGetValue(date,out n);result.Add(J.Obj("date",date,"tokens",n));}return result;
    }
    public static D Settings(object raw) {
        var s=J.Obj("language","zh","theme","light","accentColor",null,"pinned",true,"compact",false,"ringWindow","auto","elapsedArc",false,"startup",false,"notifications",false,"refreshSeconds",120,"membership",new D(),"position",null,"mainSize",null);
        foreach(string k in new[]{"pinned","compact","elapsedArc","startup","notifications"})if(J.Get(raw,k) is bool)s[k]=J.Get(raw,k);
        foreach(var p in new[]{new[]{"language","zh","zh-TW","en"},new[]{"theme","light","dark","system"},new[]{"ringWindow","auto","five","week"}})if(p.Skip(1).Contains(J.S(raw,p[0])))s[p[0]]=J.S(raw,p[0]);
        if(Regex.IsMatch(J.S(raw,"accentColor"),"^#[0-9a-fA-F]{6}$"))s["accentColor"]=J.S(raw,"accentColor").ToLowerInvariant();
        if(new[]{60d,120d,300d,600d}.Contains(J.N(raw,"refreshSeconds")))s["refreshSeconds"]=J.N(raw,"refreshSeconds");
        var pos=J.Get(raw,"position");if(J.Num(J.Get(pos,"x")).HasValue&&J.Num(J.Get(pos,"y")).HasValue)s["position"]=J.Obj("x",Math.Round(J.N(pos,"x")),"y",Math.Round(J.N(pos,"y")));
        var size=J.Get(raw,"mainSize");if(J.Num(J.Get(size,"width")).HasValue&&J.Num(J.Get(size,"height")).HasValue)s["mainSize"]=J.Obj("width",J.Clamp(J.N(size,"width"),320,900),"height",J.Clamp(J.N(size,"height"),360,1400));
        foreach(var p in J.Map(J.Get(raw,"membership")))if(Regex.IsMatch(p.Key,"^[a-f0-9]{64}$")&&J.Date(J.S(p.Value,"date"))&&new[]{"renewal","expiry"}.Contains(J.S(p.Value,"kind")))J.Map(s["membership"])[p.Key]=J.Obj("date",J.S(p.Value,"date"),"kind",J.S(p.Value,"kind"));
        return s;
    }
    public static D Demo() {double now=J.Now;return Normalize(J.Obj("email","demo@example.invalid","planType","plus"),J.Obj("rateLimitsByLimitId",J.Obj("codex",J.Obj("primary",J.Obj("usedPercent",32,"windowDurationMins",300,"resetsAt",now/1000+7980),"secondary",J.Obj("usedPercent",18,"windowDurationMins",10080,"resetsAt",now/1000+343800)),"reserve",J.Obj("limitName","gpt-reserve","normalModelSlug","gpt-5.6-luna","primary",J.Obj("usedPercent",0,"windowDurationMins",10080,"resetsAt",now/1000+500000))),"rateLimitResetCredits",J.Obj("availableCount",1,"credits",new[]{J.Obj("status","available","expiresAt",now/1000+1209600)})),now);}
}
sealed class Store {
    public readonly string DirectoryPath;
    public Store(string path){DirectoryPath=path;Directory.CreateDirectory(path);}
    public object Read(string name){try{return J.Parse(File.ReadAllText(Path.Combine(DirectoryPath,name+".json")));}catch{return null;}}
    public void Write(string name,object data){string file=Path.Combine(DirectoryPath,name+".json"),temp=file+".tmp";File.WriteAllText(temp,J.Json(data),new UTF8Encoding(false));if(File.Exists(file))File.Replace(temp,file,null);else File.Move(temp,file);}
}
// Every query uses the official client protocol. Credentials and backend logs never enter storage.
sealed class Rpc : IDisposable {
    Process child; readonly object gate=new object(); readonly Dictionary<int,TaskCompletionSource<object>> pending=new Dictionary<int,TaskCompletionSource<object>>(); readonly SemaphoreSlim startGate=new SemaphoreSlim(1,1);int id;bool ready;
    public Action<string,object> Notification;
    public int ChildId {get{lock(gate)return child==null?0:child.Id;}}
    public static string Locate() {
        var candidates=new List<string>(); string configured=Environment.GetEnvironmentVariable("CODEX_GLASS_CODEX_PATH");if(!string.IsNullOrEmpty(configured))candidates.Add(configured);
        foreach(string dir in (Environment.GetEnvironmentVariable("PATH")??"").Split(Path.PathSeparator))if(!string.IsNullOrWhiteSpace(dir))candidates.Add(Path.Combine(dir.Trim('"'),"codex.exe"));
        string local=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"OpenAI","Codex","bin");if(Directory.Exists(local))foreach(string dir in Directory.GetDirectories(local).OrderByDescending(x=>x))candidates.Add(Path.Combine(dir,"codex.exe"));
        string npm=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),"npm","node_modules","@openai","codex");
        foreach(string root in new[]{npm,Path.Combine(npm,"node_modules","@openai","codex-win32-x64")})candidates.Add(Path.Combine(root,"vendor","x86_64-pc-windows-msvc","codex","codex.exe"));
        string found=candidates.FirstOrDefault(p=>Path.IsPathRooted(p)&&File.Exists(p));if(found==null)throw new Exception("codexMissing");return found;
    }
    async Task Start() {
        await startGate.WaitAsync();try {if(ready)return;
            var p=new Process {StartInfo=new ProcessStartInfo(Locate(),"app-server") {UseShellExecute=false,CreateNoWindow=true,RedirectStandardInput=true,RedirectStandardOutput=true,RedirectStandardError=true,StandardOutputEncoding=Encoding.UTF8,StandardErrorEncoding=Encoding.UTF8}};
            p.EnableRaisingEvents=true;p.Exited+=(s,e)=>Close(p,"connectionLost");
            lock(gate)child=p;
            try {if(!p.Start())throw new Exception("startFailed");}catch{Close(p,"startFailed");throw new Exception("startFailed");}
            p.StandardInput.AutoFlush=true;
            BeginRead(p);
            await Request("initialize",J.Obj("clientInfo",J.Obj("name","codex_glass_native","title","Codex Glass","version","0.5.0")));
            Write(J.Obj("method","initialized","params",new D()));ready=true;
        }finally{startGate.Release();}
    }
    // These pumps are owned by the helper lifetime; both handle EOF and cancellation.
    void BeginRead(Process p){Task.Run(()=>Read(p));Task.Run(async()=>{try{var buffer=new char[4096];while(await p.StandardError.ReadAsync(buffer,0,buffer.Length)>0){}}catch{}});}
    async Task Read(Process p) {
        var buffer=new char[4096];var line=new StringBuilder();
        try {int n;while((n=await p.StandardOutput.ReadAsync(buffer,0,buffer.Length))>0){for(int i=0;i<n;i++){if(buffer[i]=='\n'){try{Receive(p,J.Parse(line.ToString()));}catch{}line.Clear();}else{line.Append(buffer[i]);if(line.Length>4*1024*1024)throw new Exception("invalidReply");}}}}catch{}finally{Close(p,"connectionLost");}
    }
    void Receive(Process p,object message) {
        lock(gate)if(child!=p)return;
        if(J.Get(message,"id")!=null) {
            if(J.Get(message,"method")!=null){Write(J.Obj("id",J.Get(message,"id"),"error",J.Obj("code",-32601,"message","Unsupported client request")));return;}
            var number=J.Num(J.Get(message,"id"));if(!number.HasValue)return;TaskCompletionSource<object> task;
            lock(gate){if(!pending.TryGetValue((int)number.Value,out task))return;pending.Remove((int)number.Value);}
            if(J.Get(message,"error")!=null){string error=J.S(J.Get(message,"error"),"message");string code=Regex.IsMatch(error,"auth|login|sign.in|credential|401|403",RegexOptions.IgnoreCase)?"signInRequired":Regex.IsMatch(error,"429|rate.limit",RegexOptions.IgnoreCase)?"rateLimited":"serverError";task.TrySetException(new Exception(code));}else task.TrySetResult(J.Get(message,"result"));
        }else if(Notification!=null)Notification(J.S(message,"method"),J.Get(message,"params"));
    }
    void Write(object value){lock(gate){if(child==null)throw new Exception("connectionLost");child.StandardInput.WriteLine(J.Json(value));}}
    async Task<object> Request(string method,object args) {
        int next=Interlocked.Increment(ref id);var t=new TaskCompletionSource<object>(TaskCreationOptions.RunContinuationsAsynchronously);lock(gate)pending[next]=t;
        try {Write(J.Obj("id",next,"method",method,"params",args??new D()));if(await Task.WhenAny(t.Task,Task.Delay(25000))!=t.Task){Stop();throw new Exception("timeout");}return await t.Task;}finally{lock(gate)pending.Remove(next);}
    }
    public async Task<object> Call(string method,object args=null){await Start();return await Request(method,args);}
    void Close(Process p,string reason){TaskCompletionSource<object>[] waiting;lock(gate){if(child!=p)return;child=null;ready=false;waiting=pending.Values.ToArray();pending.Clear();}try{if(!p.HasExited)p.Kill();}catch{}try{p.Dispose();}catch{}foreach(var t in waiting)t.TrySetException(new Exception(reason));}
    public void Stop(){Process p;lock(gate)p=child;if(p!=null)Close(p,"connectionLost");}
    public void Dispose(){Stop();}
}
}
