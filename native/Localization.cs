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
    public static void Validate(){var keys=J.Map(J.Get(messages,"en")).Keys.OrderBy(k=>k).ToArray();foreach(string code in Codes){var table=J.Map(J.Get(messages,code));if(!table.Keys.OrderBy(k=>k).SequenceEqual(keys))throw new Exception("Incomplete language: "+code);foreach(var item in table)if(!(item.Value is string))throw new Exception("Invalid translation: "+code+"/"+item.Key);}}
}
}
