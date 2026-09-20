using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using D=System.Collections.Generic.Dictionary<string,object>;
namespace CodexGlass {
static class Paint {
    public static SolidColorBrush Brush(string hex){var b=new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex));b.Freeze();return b;}
    // Keep the .NET 4.6-compatible overload for the original Windows 10 runtime.
#pragma warning disable 0618
    public static FormattedText Text(string text,double size,Brush brush,bool bold=false){return new FormattedText(text??"",CultureInfo.CurrentUICulture,FlowDirection.LeftToRight,new Typeface(new FontFamily("Segoe UI, Microsoft YaHei"),FontStyles.Normal,bold?FontWeights.SemiBold:FontWeights.Normal,FontStretches.Normal),size,brush);}
#pragma warning restore 0618
    public static void Arc(DrawingContext dc,Point c,double radius,double fraction,Pen pen){if(fraction<=0)return;if(fraction>=.99999){dc.DrawEllipse(null,pen,c,radius,radius);return;}double a=fraction*2*Math.PI-Math.PI/2;var geo=new StreamGeometry();using(var g=geo.Open()){g.BeginFigure(new Point(c.X,c.Y-radius),false,false);g.ArcTo(new Point(c.X+Math.Cos(a)*radius,c.Y+Math.Sin(a)*radius),new Size(radius,radius),0,fraction>.5,SweepDirection.Clockwise,true,false);}geo.Freeze();dc.DrawGeometry(null,pen,geo);}
    // Outline the glyphs, then draw hinted text on top; no blur effect or wallpaper sampling.
    public static void DesktopText(DrawingContext dc,FormattedText text,Point origin,double outline){
        var pen=new Pen(Brush("#243247"),outline){LineJoin=PenLineJoin.Round};
        dc.DrawGeometry(null,pen,text.BuildGeometry(origin));dc.DrawText(text,origin);
    }
}
sealed class RingView : FrameworkElement {
    public D Quota;public string Period;public Brush Accent,OuterAccent;public bool Stale,Demo,Outer;public Geometry Logo;
    public RingView(){Width=92;Height=126;Cursor=Cursors.Hand;Focusable=true;}
    protected override void OnRender(DrawingContext dc){
        base.OnRender(dc);double left=Quota==null?-1:J.N(Quota,"remaining");Brush color=Stale||left<0?Paint.Brush("#98A5B6"):left<=10?Paint.Brush("#EF5B58"):left<=25?Paint.Brush("#F5A33C"):Accent;
        var center=new Point(46,42);dc.DrawEllipse(Paint.Brush("#243950"),null,center,30,30);dc.DrawEllipse(null,new Pen(Paint.Brush("#57687A"),5),center,30,30);
        Paint.Arc(dc,center,30,Math.Max(0,left)/100,new Pen(color,5){StartLineCap=PenLineCap.Round,EndLineCap=PenLineCap.Round});
        if(Outer&&Quota!=null&&J.N(Quota,"resetsAt")>0&&J.N(Quota,"minutes")>0)Paint.Arc(dc,center,36,J.Clamp(1-(J.N(Quota,"resetsAt")-J.Now)/(J.N(Quota,"minutes")*60000),0,1),new Pen(OuterAccent??Accent,2){StartLineCap=PenLineCap.Round,EndLineCap=PenLineCap.Round});
        if(Logo!=null){dc.PushTransform(new TranslateTransform(29,25));dc.PushTransform(new ScaleTransform(34/24.0,34/24.0));dc.DrawGeometry(Brushes.White,null,Logo);dc.Pop();dc.Pop();}
        var value=Paint.Text(left<0?"—":Math.Floor(left)+"%",23,Brushes.White,true);Paint.DesktopText(dc,value,new Point((92-value.Width)/2,80),2);
        var period=Paint.Text((Stale?"◷ ":"")+(Period??""),10,Brushes.White);Paint.DesktopText(dc,period,new Point((92-period.Width)/2,107),1.6);
        if(Demo){var demo=Paint.Text("DEMO",7,Paint.Brush("#D0D9E5"));dc.DrawText(demo,new Point((92-demo.Width)/2,120));}
    }
}
sealed class BarChart : FrameworkElement {
    public List<D> Days;public Brush Accent,Muted;public BarChart(List<D> days,Brush accent,Brush muted){Days=days;Accent=accent;Muted=muted;Height=138;Focusable=true;MouseMove+=Hover;MouseLeave+=(s,e)=>{tipIndex=-1;InvalidateVisual();};KeyDown+=(s,e)=>{if(e.Key==Key.Right||e.Key==Key.Left){tipIndex=(tipIndex+(e.Key==Key.Right?1:-1)+Days.Count)%Days.Count;InvalidateVisual();e.Handled=true;}};GotKeyboardFocus+=(s,e)=>{tipIndex=0;InvalidateVisual();};LostKeyboardFocus+=(s,e)=>{tipIndex=-1;InvalidateVisual();};}
    int tipIndex=-1;void Hover(object sender,MouseEventArgs e){int index=(int)(e.GetPosition(this).X/Math.Max(1,ActualWidth)*Days.Count);index=Math.Max(0,Math.Min(Days.Count-1,index));if(index!=tipIndex){tipIndex=index;InvalidateVisual();}}
    protected override void OnRender(DrawingContext dc){base.OnRender(dc);if(Days.Count==0||ActualWidth<=0)return;dc.DrawRectangle(Brushes.Transparent,null,new Rect(0,0,ActualWidth,Height));double slot=ActualWidth/Days.Count, max=Math.Max(1,Days.Max(d=>J.N(d,"tokens")));dc.DrawLine(new Pen(new SolidColorBrush(Color.FromArgb(40,120,140,160)),1),new Point(0,114),new Point(ActualWidth,114));
        for(int i=0;i<Days.Count;i++){double? value=J.Num(J.Get(Days[i],"tokens"));double x=i*slot,w=Math.Max(1,slot-3);if(!value.HasValue){dc.DrawLine(new Pen(Muted,1){DashStyle=DashStyles.Dot},new Point(x,113),new Point(x+w,113));}else{double h=Math.Max(2,value.Value/max*88);dc.DrawRoundedRectangle(Accent,null,new Rect(x,114-h,w,h),1.5,1.5);}}
        var start=Paint.Text(J.S(Days[0],"date").Substring(5).Replace('-','/'),10,Muted);var end=Paint.Text(J.S(Days[Days.Count-1],"date").Substring(5).Replace('-','/'),10,Muted);dc.DrawText(start,new Point(0,120));dc.DrawText(end,new Point(ActualWidth-end.Width,120));
        if(tipIndex>=0){var d=Days[tipIndex];string label=J.S(d,"date")+" · "+(J.Get(d,"tokens")==null?"—":J.N(d,"tokens").ToString("N0")+" tokens");var tip=Paint.Text(label,10,Muted);dc.DrawText(tip,new Point(Math.Max(0,ActualWidth-tip.Width),0));}
    }
}
}
