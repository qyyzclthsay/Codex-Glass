using System;
using System.Globalization;
using System.Linq;
namespace CodexGlass {
static class Localization {
    public static readonly string[] Codes={"zh","zh-TW","en"};
    public static readonly string[] Names={"简体中文","繁體中文","English"};
    static readonly object messages=J.Parse(GlassWindow.Resource("messages.json"));
    public static string Text(string language,string key){return J.S(J.Get(messages,language),key,J.S(J.Get(messages,"en"),key,key));}
    public static CultureInfo Culture(string language){return CultureInfo.GetCultureInfo(language=="zh"?"zh-CN":language=="zh-TW"?"zh-TW":"en-US");}
    public static string Tokens(double? value,string language,bool total){
        if(!value.HasValue||double.IsNaN(value.Value)||double.IsInfinity(value.Value)||value.Value<0)return "—";
        double amount=value.Value,scale;string unit;bool chinese=language=="zh"||language=="zh-TW";
        if(chinese){scale=total?100000000:10000;unit=total?(language=="zh-TW"?"億":"亿"):(language=="zh-TW"?"萬":"万");}
        else{scale=amount>=1000000000?1000000000:amount>=1000000?1000000:amount>=1000?1000:1;unit=scale==1000000000?"B":scale==1000000?"M":scale==1000?"K":"";}
        // A small positive count must not look like an actual zero after rounding.
        string number=amount==0?"0":chinese&&amount/scale<.01?"<0.01":(amount/scale).ToString(scale==1?"N0":"0.00",Culture(language));
        return number+(unit==""?"":" "+unit);
    }
    public static void Validate(){var keys=J.Map(J.Get(messages,"en")).Keys.OrderBy(k=>k).ToArray();foreach(string code in Codes){var table=J.Map(J.Get(messages,code));if(!table.Keys.OrderBy(k=>k).SequenceEqual(keys))throw new Exception("Incomplete language: "+code);foreach(var item in table)if(!(item.Value is string))throw new Exception("Invalid translation: "+code+"/"+item.Key);}}
}
}
