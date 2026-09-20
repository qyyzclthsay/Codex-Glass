using System;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Windows;
using System.Windows.Threading;
[assembly: AssemblyTitle("Codex Glass")]
[assembly: AssemblyProduct("Codex Glass")]
[assembly: AssemblyVersion("0.5.1.0")]
[assembly: AssemblyFileVersion("0.5.1.0")]
namespace CodexGlass {
static class Program {
    public static string[] Arguments;public static string QaDirectory;
    [STAThread]public static int Main(string[] args){Arguments=args;if(args.Length==1&&args[0]=="app-server"&&Environment.GetEnvironmentVariable("CODEX_GLASS_TEST_RPC")=="1"){NativeTests.FakeRpc();return 0;}bool qa=Array.IndexOf(args,"--smoke-test")>=0,self=Array.IndexOf(args,"--self-test")>=0,measure=Array.IndexOf(args,"--measure")>=0,demo=qa||Array.IndexOf(args,"--demo")>=0;
        QaDirectory=Environment.GetEnvironmentVariable("CODEX_GLASS_QA_DIR")??Path.Combine(Path.GetTempPath(),"codex-glass-native-qa");if(qa||self||measure)Directory.CreateDirectory(QaDirectory);
        if(self){try{NativeTests.Run();return 0;}catch(Exception ex){File.WriteAllText(Path.Combine(QaDirectory,"self-test-error.txt"),ex.ToString());return 1;}}
        string directory=Environment.GetEnvironmentVariable("CODEX_GLASS_DATA_DIR")??(demo?Path.Combine(QaDirectory,"profile"):Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),"codex-usage-widget"));
        string key="Local\\CodexGlassNative-"+Model.Identity(J.Obj("id",directory.ToLowerInvariant()));bool first;
        using(var mutex=new Mutex(true,key,out first))using(var signal=new EventWaitHandle(false,EventResetMode.AutoReset,key+"-show")){
            if(!first){signal.Set();return 0;}
            System.Windows.Media.RenderOptions.ProcessRenderMode=System.Windows.Interop.RenderMode.SoftwareOnly;
            var app=new Application{ShutdownMode=ShutdownMode.OnExplicitShutdown};GlassWindow window=null;int exit=0;
            app.DispatcherUnhandledException+=(s,e)=>{e.Handled=true;exit=1;if(qa||measure)File.WriteAllText(Path.Combine(QaDirectory,"error.txt"),e.Exception.ToString());else MessageBox.Show("Codex Glass 无法完成操作，请重试。 / Unable to complete this action. Please retry.","Codex Glass");if(qa||measure)app.Shutdown(1);};
            try{var service=new Service(directory,demo);window=new GlassWindow(service,qa);app.MainWindow=window;var wait=ThreadPool.RegisterWaitForSingleObject(signal,(s,t)=>app.Dispatcher.BeginInvoke(new Action(window.Reveal)),null,-1,false);
                if(qa)window.Loaded+=async(s,e)=>{try{await window.RunQA();}catch(Exception error){File.WriteAllText(Path.Combine(QaDirectory,"error.txt"),error.ToString());exit=1;}finally{window.Quit();}};
                if(measure)window.Loaded+=async(s,e)=>{try{await window.MeasureLive();}catch(Exception error){File.WriteAllText(Path.Combine(QaDirectory,"error.txt"),error.ToString());exit=1;}finally{window.Quit();}};
                // Opt-in discoverability for desktop input QA; normal widget windows stay out of the taskbar.
                if(demo&&Array.IndexOf(args,"--interactive-test")>=0){window.ShowInTaskbar=true;window.Title="Codex Glass - QA";}
                window.Show();if(Array.IndexOf(args,"--hidden")>=0)window.Hide();app.Run();wait.Unregister(null);
            }catch(Exception error){exit=1;if(qa||measure)File.WriteAllText(Path.Combine(QaDirectory,"error.txt"),error.ToString());else MessageBox.Show("Codex Glass 启动失败，请检查数据目录是否可写。 / Unable to start. Check the data directory.","Codex Glass");}
            return exit;
        }
    }
}
}
