#!/usr/bin/env bash
# Public snapshot regression against Guilds 1.5.1's store shape and native ZDO APIs.
# Guilds.dll SHA256: 1e6421079246f52aa31561adb5c6e01c971cc417cc4ca0f9d5a33c1896e4ce44.
# Siege state comes from Oathbound 0.22.0 Warrior.Core.SiegeState (Stage 1..4 active).
set -euo pipefail
ROOT="${WEBMAP_SOURCE_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
framework="net$(dotnet --version | cut -d. -f1).0"
cat > "$work/Guilds.csproj" <<EOF
<Project Sdk="Microsoft.NET.Sdk">
<PropertyGroup><OutputType>Exe</OutputType><TargetFramework>$framework</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems><NoWarn>0649</NoWarn></PropertyGroup>
<ItemGroup>
<Compile Include="Program.cs" />
<Compile Include="$ROOT/src/forks/ValheimWebMap/Guild*.cs" />
<Compile Include="$ROOT/src/forks/ValheimWebMap/JsonWriter.cs" />
<PackageReference Include="Newtonsoft.Json" Version="13.0.4" />
</ItemGroup>
</Project>
EOF
cat > "$work/Program.cs" <<'EOF'
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using UnityEngine;
using ValheimWebMap;
class Program {
    static void Check(bool ok,string message) { if (!ok) throw new Exception("FAIL: " + message); Console.WriteLine("pass: " + message); }
    static JsonElement Row(JsonElement array,string property,string value) => array.EnumerateArray().Single(x => x.GetProperty(property).GetString()==value);
    static string Text(JsonElement row,string property) => row.GetProperty(property).GetString();
    static JsonDocument Snapshot(GuildLookup lookup) {
        var json = new JsonWriter(); json.BeginObject();
        lookup.Write(json); json.EndObject(); return JsonDocument.Parse(json.ToString());
    }
    static void Privacy(JsonElement root) {
        string[] forbidden = {"vault","coins","motd","pins","withdrawnToday","contribution"};
        void Visit(JsonElement e) {
            if(e.ValueKind==JsonValueKind.Object) foreach(var p in e.EnumerateObject()) { if(forbidden.Contains(p.Name,StringComparer.OrdinalIgnoreCase)) throw new Exception("FAIL: private guild property " + p.Name); Visit(p.Value); }
            else if(e.ValueKind==JsonValueKind.Array) foreach(var child in e.EnumerateArray()) Visit(child);
        }
        Visit(root.GetProperty("guilds"));
        string[] allowed={"id","tag","name","color","emblem","description","leader","members","startRegion","level","upgrades","buildings","relations","banner","territoryHalfSide"};
        foreach(var guild in root.GetProperty("guilds").EnumerateArray()) Check(guild.EnumerateObject().Select(p=>p.Name).OrderBy(x=>x).SequenceEqual(allowed.OrderBy(x=>x)),"guild publishes exactly the public card whitelist");
        Check(!root.GetRawText().Contains("PRIVATE_SENTINEL"),"private guild content never serialized");
    }
    static void Main(string[] args) {
        var warnings = new List<string>(); var lookup = new GuildLookup(warnings.Add);
        var players = new List<PlayerEntry> {new PlayerEntry {Id=1001,PlayerId=42,Name="Asta",HasCharacter=true,Visible=false}};
        if(args.Contains("drift")) {
            lookup.Refresh(players,args[0],"fixture"); lookup.Refresh(players,args[0],"fixture");
            using var doc = Snapshot(lookup); var state=doc.RootElement;
            Check(!state.GetProperty("guildsEnabled").GetBoolean(),"renamed GuildOf disables guild features");
            Check(state.GetProperty("guilds").GetArrayLength()==0 && state.GetProperty("claims").GetArrayLength()==0,"drift removes guild snapshots");
            Check(warnings.Count==1,"API drift warns exactly once across polls");
            Check(lookup.NameOf(42)==null && lookup.IdOf(42)==null && lookup.ColorOf(42)=="#888781","drift clears player guild identity"); return;
        }
        string configRoot=args[0]; Directory.CreateDirectory(Path.Combine(configRoot,"Lembitu.Guilds"));
        File.WriteAllText(Path.Combine(configRoot,"Lembitu.Guilds","fixture.claims.json"),"{\"Version\":1,\"Claims\":[{\"Region\":\"Skadi\",\"GuildId\":9007199254740993,\"GuildTag\":\"OAK\",\"GuildName\":\"Oak & Iron\",\"ClaimedTicks\":639273599990000000,\"ClaimedBy\":\"PRIVATE_SENTINEL\"}]}");
        var oak = new Guilds.Guild {Id=9007199254740993,Name="Oak & Iron",Tag="OAK",Color="FFD27A",Emblem="TrophyDeer",Description="Keep \"oak\"\n& iron",HasBanner=true,BannerPos=new Vector3(13000,80,-12000),Xp=5000};
        oak.Members.Add(new Guilds.Member {Pid=42,Name="Asta",Rank=0}); oak.Members.Add(new Guilds.Member {Pid=43,Name="Bryn",Rank=1}); oak.Upgrades.Add("territory",2); oak.Upgrades.Add("regen",1); oak.Relations.Add(2,Guilds.Relation.Ally);
        var ash = new Guilds.Guild {Id=2,Name="Ash",Tag="ASH",Color="5DA9FF",Emblem="TrophyBoar",HasBanner=false,Xp=0}; ash.Members.Add(new Guilds.Member {Pid=44,Name="Cato",Rank=0}); ash.Relations.Add(oak.Id,Guilds.Relation.War);
        Guilds.GuildServer.Seed(oak,ash);
        SeparateSpawns.Plugin.LayoutCache.Current.GroupSpawnPositions.Add("Skadi",new Vector3(700,20,-900));
        SeparateSpawns.Plugin.LayoutCache.Current.GroupSpawnPositions.Add("Fenrir",new Vector3(-600,30,800));
        var ward = new ZDO(1,new Vector3(13020,40,-12030),123); ward.Set("Guilds_WardGuild",oak.Id); ZDOMan.instance.Add(ward);
        var orphanWard = new ZDO(2,new Vector3(50,40,60),123); orphanWard.Set("Guilds_WardGuild",999L); ZDOMan.instance.Add(orphanWard);
        ZNetScene.instance.Prefabs.Add(123,new GameObject {Area=new PrivateArea {m_radius=27.5f}});
        var outpost = new ZDO(3,new Vector3(-14000,30,12500),456); outpost.Set("creator",44L); outpost.Set("oathbound.siege.state","{\"Version\":1,\"Tier\":2,\"Stage\":1,\"Run\":\"fixture\",\"Paused\":false}"); ZDOMan.instance.Add(outpost);
        lookup.Refresh(players,configRoot,"fixture");
        using(var doc=Snapshot(lookup)) {
            var state=doc.RootElement; Check(state.GetProperty("guildsEnabled").GetBoolean() && warnings.Count==0,"real Guilds shape enables snapshots without warning");
            var guilds=state.GetProperty("guilds"); var g=Row(guilds,"id","9007199254740993"); var other=Row(guilds,"id","2");
            Check(Text(g,"name")=="Oak & Iron" && Text(g,"tag")=="OAK" && Text(g,"description")=="Keep \"oak\"\n& iron" && Text(g,"emblem")=="TrophyDeer","full public guild text preserves escaping and trophy emblem");
            Check(Text(g,"color")=="#b6a06b" && Text(other,"color")=="#7090b1","chosen game palette maps to fixed muted colours");
            Check(Text(g.GetProperty("leader"),"id")=="42" && Text(g.GetProperty("leader"),"name")=="Asta","leader uses native rank-zero identity");
            Check(Row(g.GetProperty("members"),"id","42").GetProperty("online").GetBoolean() && !Row(g.GetProperty("members"),"id","43").GetProperty("online").GetBoolean(),"online membership independent of location privacy");
            Check(Text(g,"startRegion")=="Skadi" && other.GetProperty("startRegion").ValueKind==JsonValueKind.Null,"claimed region and regionless guild distinguished");
            Check(g.GetProperty("level").GetInt32()==3 && other.GetProperty("level").GetInt32()==1,"server guild level API respected");
            Check(Row(g.GetProperty("upgrades"),"name","territory").GetProperty("tier").GetInt32()==2,"upgrade tiers published");
            Check(g.GetProperty("buildings").EnumerateArray().Single().GetProperty("name").GetString()=="longhouse" && g.GetProperty("buildings")[0].EnumerateObject().Count()==1,"built kinds published without quantities");
            Check(Text(g.GetProperty("relations")[0],"guildId")=="2" && Text(g.GetProperty("relations")[0],"relation")=="ally" && Text(other.GetProperty("relations")[0],"relation")=="war","ally and war names published");
            Check(g.GetProperty("banner").GetProperty("x").GetSingle()==13000 && g.GetProperty("banner").GetProperty("z").GetSingle()==-12000 && g.GetProperty("territoryHalfSide").GetSingle()==70 && other.GetProperty("banner").ValueKind==JsonValueKind.Null,"non-default native territory geometry and absent banner");
            var claims=state.GetProperty("claims"); var territory=claims.EnumerateArray().Single(x=>Text(x,"kind")=="territory");
            Check(territory.GetProperty("halfSide").GetSingle()==70 && territory.GetProperty("x").GetSingle()==13000 && territory.GetProperty("z").GetSingle()==-12000 && Text(territory,"guildId")=="9007199254740993","territory matches upgraded native 140-metre square at expanded coordinates");
            var regions=claims.EnumerateArray().Where(x=>Text(x,"kind")=="region").ToArray(); var claimed=regions.Single(x=>Text(x,"name")=="Skadi"); var unclaimed=regions.Single(x=>Text(x,"name")=="Fenrir");
            Check(claimed.GetProperty("x").GetSingle()==700 && claimed.GetProperty("z").GetSingle()==-900 && Text(claimed,"claimedDay")=="2026-10-11" && Text(claimed,"color")=="#b6a06b","start point uses layout and UTC calendar claim date");
            Check(unclaimed.GetProperty("guildId").ValueKind==JsonValueKind.Null && Text(unclaimed,"color")=="#888781" && unclaimed.GetProperty("claimedDay").ValueKind==JsonValueKind.Null,"unclaimed start region remains grey and undated");
            var wards=claims.EnumerateArray().Where(x=>Text(x,"kind")=="ward").ToArray(); Check(wards.All(x=>x.GetProperty("radius").GetSingle()==27.5f) && wards.Any(x=>Text(x,"color")=="#b6a06b") && wards.Any(x=>Text(x,"color")=="#888781"),"bound ward uses actual prefab radius and orphan is grey");
            var post=claims.EnumerateArray().Single(x=>Text(x,"kind")=="outpost"); Check(Text(post,"guildId")=="2" && Text(post,"color")=="#7090b1" && Text(post.GetProperty("siege"),"stage")=="warning" && post.GetProperty("x").GetSingle()==-14000,"outpost uses offline builder guild and live warning stage");
            Privacy(state);
            string export=Environment.GetEnvironmentVariable("WEBMAP_GUILDS_JSON");
            if(!string.IsNullOrEmpty(export)) File.WriteAllText(export,state.GetRawText());
        }
        Check(lookup.NameOf(42)=="Oak & Iron" && lookup.IdOf(42)=="9007199254740993" && lookup.ColorOf(42)=="#b6a06b" && lookup.IdOf(99)==null && lookup.ColorOf(99)=="#888781","player guild identities share public snapshot palette");
        foreach(var stage in new[]{2,3,4,5,6,0}) {
            outpost.Set("oathbound.siege.state","{\"Version\":1,\"Stage\":"+stage+",\"Paused\":false}"); lookup.Refresh(players,configRoot,"fixture");
            using var doc=Snapshot(lookup); var post=doc.RootElement.GetProperty("claims").EnumerateArray().Single(x=>Text(x,"kind")=="outpost");
            if(stage>=2 && stage<=4) Check(Text(post.GetProperty("siege"),"stage")==new Dictionary<int,string>{{2,"first wave"},{3,"second wave"},{4,"commander"}}[stage],"live siege refresh stage " + stage);
            else Check(post.GetProperty("siege").ValueKind==JsonValueKind.Null,"ended or idle siege disappears while outpost persists " + stage);
        }
        outpost.Set("oathbound.siege.state","{\"Version\":1,\"Stage\":4,\"Paused\":true}"); lookup.Refresh(players,configRoot,"fixture");
        using(var doc=Snapshot(lookup)) Check(Text(doc.RootElement.GetProperty("claims").EnumerateArray().Single(x=>Text(x,"kind")=="outpost").GetProperty("siege"),"stage")=="commander (suspended)","paused active siege retains stage with suspended label");
        var guildlessPost=new ZDO(4,new Vector3(100,20,200),456);guildlessPost.Set("creator",99L);guildlessPost.Set("oathbound.siege.state","{\"Version\":1,\"Stage\":0}");ZDOMan.instance.Add(guildlessPost);lookup.Refresh(players,configRoot,"fixture");
        using(var doc=Snapshot(lookup)) {var post=doc.RootElement.GetProperty("claims").EnumerateArray().Single(x=>Text(x,"kind")=="outpost"&&x.GetProperty("x").GetSingle()==100);Check(post.GetProperty("guildId").ValueKind==JsonValueKind.Null && Text(post,"color")=="#888781","guildless builder outpost is grey");}
        PrivateArea.m_allAreas.Add(new PrivateArea {m_radius=35,View=new ZNetView {Data=ward}});
        lookup.Refresh(players,configRoot,"fixture"); using(var doc=Snapshot(lookup)) Check(doc.RootElement.GetProperty("claims").EnumerateArray().Single(x=>Text(x,"kind")=="ward" && Text(x,"guildId")==oak.Id.ToString()).GetProperty("radius").GetSingle()==35,"loaded ward radius overrides prefab radius");
        string[] palette={"FFD27A","FF8C42","FF5A4E","D9435E","C77DFF","8A7CFF","5DA9FF","4ED6E0","55D68A","A6E05A","E8E8E8","B08D5A"};
        string[] muted={"#b6a06b","#b78059","#ae6b62","#995d6b","#977ca9","#817ba9","#7090b1","#71a2a5","#76a084","#97a76c","#b3b1a8","#998568"};
        for(int i=0;i<palette.Length;i++) {oak.Color=palette[i];lookup.Refresh(players,configRoot,"fixture");Check(lookup.ColorOf(43)==muted[i],"fixed muted palette " + palette[i]);}
        oak.Color="FF5A4E"; oak.Description="Changed"; oak.HasBanner=false; oak.Members.RemoveAt(0); ash.Members.Add(new Guilds.Member {Pid=42,Name="Asta",Rank=1}); File.WriteAllText(Path.Combine(configRoot,"Lembitu.Guilds","fixture.claims.json"),"{\"Version\":1,\"Claims\":[]}");
        lookup.Refresh(players,configRoot,"fixture"); using(var doc=Snapshot(lookup)) {
            var state=doc.RootElement; Check(Text(Row(state.GetProperty("guilds"),"id",oak.Id.ToString()),"description")=="Changed" && lookup.IdOf(42)=="2" && lookup.ColorOf(42)=="#7090b1","guild edits and membership moves refresh together");
            Check(!state.GetProperty("claims").EnumerateArray().Any(x=>Text(x,"kind")=="territory") && state.GetProperty("claims").EnumerateArray().Where(x=>Text(x,"kind")=="region").All(x=>x.GetProperty("guildId").ValueKind==JsonValueKind.Null),"banner loss and claim release remove stale claims");
        }
        Console.WriteLine("webmap guild snapshots: all checks passed");
    }
}
namespace ValheimWebMap { internal struct PlayerEntry {public long Id,PlayerId; public string Name; public bool Visible,HasCharacter;} }
namespace Guilds {
    public enum Relation {Neutral,Ally,War}
    public class Member {public long Pid; public string Name; public int Rank; public long WithdrawnToday=123,Contribution=456;}
    public class Guild {
        public long Id,Xp,Coins=111; public string Name,Tag,Color,Emblem,Description,Motd="PRIVATE_SENTINEL"; public bool HasBanner; public Vector3 BannerPos;
        public List<Member> Members=new(); public List<string> Vault=new(){"PRIVATE_SENTINEL"},Pins=new(){"PRIVATE_SENTINEL"}; public Dictionary<string,int> Upgrades=new(); public Dictionary<long,Relation> Relations=new();
        public Member Leader=>Members.FirstOrDefault(m=>m.Rank==0); public int Tier(string key)=>Upgrades.GetValueOrDefault(key);
    }
    internal static class GuildServer {
        private static readonly List<Guild> Guilds=new(); public static void Seed(params Guild[] guilds) {Guilds.Clear();Guilds.AddRange(guilds);} public static void EnsureLoaded() {}
#if DRIFT
        public static Guild RenamedGuildOf(long pid)=>Guilds.FirstOrDefault(g=>g.Members.Any(m=>m.Pid==pid));
#else
        public static Guild GuildOf(long pid)=>Guilds.FirstOrDefault(g=>g.Members.Any(m=>m.Pid==pid));
#endif
        public static float HalfSide(Guild g,int extraTiers)=>(Plugin.TerritoryBaseSize.Value+(g.Tier("territory")+extraTiers)*Plugin.TerritorySizePerUpgrade.Value)/2f;
        public static int BuildingCount(long gid,string kind)=>gid==9007199254740993 && kind=="longhouse"?2:0;
    }
    public class Entry<T> {public T Value {get;set;} public Entry(T value){Value=value;}}
    public static class Plugin {public static Entry<int> TerritoryBaseSize=new(100),TerritorySizePerUpgrade=new(20),LevelXpBase=new(1000),MaxLevel=new(20);public static Entry<float> LevelXpGrowth=new(2);}
    // The pinned Progress.LevelOf/XpToNext algorithm; the worked fixture pays 1000+2000 XP for level 3.
    internal static class Progress {public static int LevelOf(long xp) {int level=1;long need=Next(level);while(level<Plugin.MaxLevel.Value && xp>=need){xp-=need;level++;need=Next(level);}return level;}static long Next(int level)=>(long)Math.Round(Plugin.LevelXpBase.Value*Math.Pow(Plugin.LevelXpGrowth.Value,level-1));}
    public class BuildingDef {public string Id;}
    internal static class Buildings {public static readonly List<BuildingDef> Defs=new(){new BuildingDef {Id="longhouse"},new BuildingDef {Id="armory"}};}
}
namespace SeparateSpawns {
    internal static class Plugin {internal static WorldLayoutCache LayoutCache {get;}=new();}
    internal class WorldLayoutCache {public WorldLayoutData Current {get;}=new();}
    internal class WorldLayoutData {public Dictionary<string,Vector3> GroupSpawnPositions=new();}
}
namespace UnityEngine {
    public struct Vector3 {public float x,y,z; public Vector3(float x,float y,float z){this.x=x;this.y=y;this.z=z;}}
    public class GameObject {public PrivateArea Area; public T GetComponent<T>() where T:class=>Area as T;}
}
public class PrivateArea {public static List<PrivateArea> m_allAreas=new(); public float m_radius; public ZNetView View; public T GetComponent<T>() where T:class=>View as T;}
public class ZNetView {public ZDO Data; public ZDO GetZDO()=>Data;}
public static class ZDOVars {public static int s_creator="creator".GetStableHashCode();}
public struct ZDOID : IEquatable<ZDOID> {public long UserID; public uint ID; public static ZDOID None=>default; public ZDOID(long user,uint id){UserID=user;ID=id;} public override string ToString()=>UserID+":"+ID; public bool Equals(ZDOID b)=>UserID==b.UserID&&ID==b.ID; public override bool Equals(object b)=>b is ZDOID other&&Equals(other); public override int GetHashCode()=>HashCode.Combine(UserID,ID);}
public class ZDO {
    public ZDOID m_uid; public Dictionary<int,long> Longs=new(); public Dictionary<int,string> Strings=new(); Vector3 pos; int prefab;
    public ZDO(uint id,Vector3 position,int prefab){m_uid=new ZDOID(100,id);pos=position;this.prefab=prefab;}
    public Vector3 GetPosition()=>pos; public int GetPrefab()=>prefab;
    public long GetLong(string key,long fallback=0)=>GetLong(key.GetStableHashCode(),fallback); public long GetLong(int key,long fallback=0)=>Longs.GetValueOrDefault(key,fallback);
    public string GetString(string key,string fallback="")=>GetString(key.GetStableHashCode(),fallback); public string GetString(int key,string fallback="")=>Strings.GetValueOrDefault(key,fallback);
    public void Set(string key,long value)=>Longs[key.GetStableHashCode()]=value; public void Set(string key,string value)=>Strings[key.GetStableHashCode()]=value;
}
public class ZDOMan {public static ZDOMan instance=new(); public Dictionary<ZDOID,ZDO> Store=new(); public ZDO GetZDO(ZDOID id)=>Store.GetValueOrDefault(id); public void Add(ZDO z)=>Store.Add(z.m_uid,z);}
public static class ZDOExtraData {
    public enum Type {Float,Vec3,Quaternion,Int,Long,String,ByteArray}
    public static List<ZDOID> GetAllZDOIDsWithHash(Type type,int hash)=>ZDOMan.instance.Store.Where(p=>type==Type.Long?p.Value.Longs.ContainsKey(hash):type==Type.String&&p.Value.Strings.ContainsKey(hash)).Select(p=>p.Key).ToList();
}
public class ZNetScene {public static ZNetScene instance=new(); public Dictionary<int,GameObject> Prefabs=new(); public GameObject GetPrefab(int hash)=>Prefabs.GetValueOrDefault(hash);}
public static class StringExtensionMethods {public static int GetStableHashCode(this string value) {unchecked {int a=5381,b=a;for(int i=0;i<value.Length && value[i]!='\0';i+=2){a=((a<<5)+a)^value[i];if(i==value.Length-1||value[i+1]=='\0')break;b=((b<<5)+b)^value[i+1];}return a+b*1566083941;}}}
EOF
dotnet run --project "$work/Guilds.csproj" --nologo -- "$work/config"
dotnet run --project "$work/Guilds.csproj" --nologo -p:DefineConstants=DRIFT -- "$work/config" drift
node "$(dirname "$0")/webmap-guilds-ui.mjs" "$ROOT"
