using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using D=System.Collections.Generic.Dictionary<string,object>;
namespace CodexGlass {
sealed class Service : IDisposable {
    public readonly Store Store; public D Settings,Snapshot,Daily; public string Identity,Fingerprint,Status="loading",Error,DailyError,LoginId; public bool Busy,DailyBusy;public readonly bool Demo;
    public Action Changed; public Action<string,object> RpcNotice;public Action<string> Alert;public int Failures;public readonly Rpc Rpc=new Rpc();readonly SemaphoreSlim serial=new SemaphoreSlim(1,1);D alertMemory;int generation;
    public Service(string directory,bool demo){Store=new Store(directory);Settings=Model.Settings(Store.Read("settings"));alertMemory=J.Map(Store.Read("alerts"));Demo=demo;Rpc.Notification=(m,p)=>{if(RpcNotice!=null)RpcNotice(m,p);};}
    public void Emit(){if(Changed!=null)Changed();}
    public void Save(){Settings=Model.Settings(Settings);Store.Write("settings",Settings);}
    public void Forget(){Identity=null;Fingerprint=null;Snapshot=null;Daily=null;DailyError=null;generation++;}
    public D Member {get {return J.Map(J.Get(J.Get(Settings,"membership"),Identity??""));}}
    public bool SetMember(string account,string date,string kind){if(account==null||account!=Identity)return false;var members=J.Map(Settings["membership"]);if(date=="")members.Remove(account);else if(J.Date(date)&&new[]{"renewal","expiry"}.Contains(kind))members[account]=J.Obj("date",date,"kind",kind);else return false;Save();return true;}
    async Task<object> Account(){var result=await Rpc.Call("account/read",J.Obj("refreshToken",false));var a=J.Get(result,"account");if(J.S(a,"type")!="chatgpt")throw new Exception("signInRequired");return a;}
    public async Task Refresh(){if(Busy)return;Busy=true;Emit();await serial.WaitAsync();try{
        D result;
        if(Demo)result=Model.Demo();else{
            var a=await Account();string fp=Model.Identity(a);if(Fingerprint!=fp){Forget();Fingerprint=fp;}
            var limits=await Rpc.Call("account/rateLimits/read");var after=await Account();if(Model.Identity(after)!=fp){Forget();throw new Exception("accountChanged");}
            result=Model.Normalize(after,limits,J.Now);
        }
        if(Identity!=J.Str(J.Get(result,"identity"))){Daily=null;generation++;}Identity=J.Str(J.Get(result,"identity"));Snapshot=result;Status="live";Error=null;Failures=0;
        if(Demo){Fingerprint=Identity;if(Member.Count==0&&Identity!=null)J.Map(Settings["membership"])[Identity]=J.Obj("date",DateTime.Today.AddDays(19).ToString("yyyy-MM-dd"),"kind","renewal");}
        else if(Identity!=null){Store.Write("cache",Snapshot);CheckAlerts();}
    }catch(Exception e){Failures++;Error=Code(e);if(new[]{"signInRequired","accountChanged","codexMissing"}.Contains(Error)){Forget();Status="error";}else{Snapshot=Model.Cache(Snapshot??Store.Read("cache"),Identity,J.Now);Status=Snapshot==null?"error":"stale";}}
    finally{Busy=false;if(LoginId==null)Rpc.Stop();serial.Release();Emit();}}
    public async Task ReadDaily(){if(DailyBusy)return;DailyBusy=true;DailyError=null;Emit();await serial.WaitAsync();string account=Identity,fp=Fingerprint;int current=generation;try{
        if(account==null)throw new Exception("signInRequired");
        if(Demo){Daily=Model.Usage(J.Obj("dailyUsageBuckets",Enumerable.Range(0,30).Select(i=>J.Obj("startDate",DateTime.Today.AddDays(-i).ToString("yyyy-MM-dd"),"tokens",i==2?0:Math.Round(1400000+(Math.Sin(i*1.7)+1)*1600000))).ToArray()),J.Now);return;}
        var before=await Account();if(Model.Identity(before)!=fp||current!=generation)throw new Exception("accountChanged");
        if(Daily!=null&&J.Now-J.N(Daily,"observedAt")<60000)return;
        var raw=await Rpc.Call("account/usage/read");var after=await Account();if(Model.Identity(after)!=fp||Identity!=account||current!=generation)throw new Exception("accountChanged");
        Daily=Model.Usage(raw,J.Now);
    }catch(Exception e){DailyError=Code(e);Daily=null;if(DailyError=="accountChanged"||DailyError=="signInRequired"){string failure=DailyError;Forget();Status="error";Error=failure;DailyError=failure;}}
    finally{DailyBusy=false;if(LoginId==null)Rpc.Stop();serial.Release();Emit();}}
    public static string Code(Exception e){string msg=e.Message;return new[]{"signInRequired","accountChanged","codexMissing","timeout","connectionLost","startFailed","invalidReply","rateLimited","loginFailed"}.Contains(msg)?msg:"serverError";}
    public async Task<string> Login(){await serial.WaitAsync();try{var result=await Rpc.Call("account/login/start",J.Obj("type","chatgpt"));string url=J.S(result,"authUrl");Uri uri;if(!Uri.TryCreate(url,UriKind.Absolute,out uri)||uri.Scheme!="https"||!new[]{"auth.openai.com","auth0.openai.com","chatgpt.com"}.Contains(uri.Host)||uri.UserInfo!="")throw new Exception("loginFailed");LoginId=J.S(result,"loginId");return url;}catch{Error="loginFailed";Rpc.Stop();return null;}finally{serial.Release();Emit();}}
    public async Task CancelLogin(){await serial.WaitAsync();try{if(LoginId!=null)await Rpc.Call("account/login/cancel",J.Obj("loginId",LoginId));}catch{}finally{LoginId=null;Rpc.Stop();serial.Release();Emit();}}
    string T(string key){return Localization.Text(J.S(Settings,"language"),key);}
    void CheckAlerts(){if(!J.B(Settings,"notifications")||Snapshot==null||Identity==null)return;
        foreach(var w in J.Items(Snapshot["windows"]))if(J.N(w,"resetsAt")>J.Now&&J.N(w,"remaining")<=20){int level=J.N(w,"remaining")<=5?5:J.N(w,"remaining")<=10?10:20;string key="quota:"+Identity+":"+J.S(w,"id")+":"+J.N(w,"resetsAt");if(!alertMemory.ContainsKey(key)||Convert.ToDouble(alertMemory[key])>level){alertMemory[key]=level;Notify((J.N(w,"minutes")==10080?T("week"):"Codex")+" · "+Math.Floor(J.N(w,"remaining"))+"% "+T("remaining"));}}
        string date=J.S(Member,"date");if(J.Date(date)){int days=(DateTime.ParseExact(date,"yyyy-MM-dd",System.Globalization.CultureInfo.InvariantCulture)-DateTime.Today).Days;string key="member:"+Identity+":"+date+":"+days;if(days>=0&&days<=3&&!alertMemory.ContainsKey(key)){alertMemory[key]=1;Notify(string.Format(Localization.Culture(J.S(Settings,"language")),T("memberAlert"),days));}}
        object reset=Snapshot["resets"];double expiry=J.N(reset,"expiresAt");string creditKey="credit:"+Identity+":"+expiry+":"+DateTime.Today.ToString("yyyy-MM-dd");if(J.N(reset,"count")>0&&expiry>J.Now&&expiry-J.Now<3*86400000&&!alertMemory.ContainsKey(creditKey)){alertMemory[creditKey]=1;Notify(T("resetAlert"));}
        if(alertMemory.Count>200)alertMemory=new D(alertMemory.Skip(alertMemory.Count-200).ToDictionary(p=>p.Key,p=>p.Value));Store.Write("alerts",alertMemory);
    }
    void Notify(string text){if(Alert!=null)Alert(text);}
    public void Dispose(){Rpc.Dispose();}
}
}
