using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using BepInEx.Logging;
using Mono.Cecil;

namespace Lembitu.Updater;

/// <summary>Installs the Pack update Lembitu.Updater staged in the previous session. BepInEx's
/// preloader runs Initialize before the chainloader loads any plugin, so every plugin file is free
/// to replace. It patches no assembly.</summary>
public static class UpdaterPatcher
{
    public static IEnumerable<string> TargetDLLs { get; } = Array.Empty<string>();

    public static void Patch(AssemblyDefinition assembly) { }

    public static void Initialize()
    {
        ManualLogSource log = Logger.CreateLogSource("Lembitu.Updater");
        try { StagedUpdate.Apply(PackFiles.PackRoot(), log); }
        catch (Exception error) { log.LogError("Pack update step failed: " + error); }
        finally { Logger.Sources.Remove(log); }
    }
}

internal static class StagedUpdate
{
    /// <summary>All or nothing. Every staged file is checked against the plan first. Then each file
    /// the update replaces or removes is moved aside (Windows lets a file in use be renamed, not
    /// overwritten); if any move fails, everything moved goes back and the install is unchanged.
    /// Only then do the new files go in. The outcome is left in result.txt for the plugin to show.</summary>
    internal static void Apply(string root, ManualLogSource log)
    {
        string stage = PackFiles.Under(root, PackFiles.StageDir);
        RemoveLeftovers(root, stage, log);
        string planFile = Path.Combine(stage, PackFiles.PlanFile);
        if (!File.Exists(planFile)) return;
        string staged = Path.Combine(stage, PackFiles.StagedDir);
        string result;
        try
        {
            UpdatePlan plan = UpdatePlan.Parse(File.ReadAllText(planFile));
            foreach (var (sha, path) in plan.Writes)
            {
                string file = PackFiles.Under(staged, path);
                if (!File.Exists(file) || PackFiles.Sha256File(file) != sha)
                    throw new InvalidDataException("the staged copy of " + path + " is missing or damaged");
            }
            var aside = new List<(string Target, string Backup)>();
            var placed = new List<string>();
            try
            {
                foreach (string path in plan.Writes.Select(w => w.Path).Concat(plan.Deletes))
                {
                    string target = PackFiles.Under(root, path);
                    if (!File.Exists(target)) continue;
                    string backup = target + PackFiles.BackupSuffix;
                    if (File.Exists(backup)) File.Delete(backup);
                    File.Move(target, backup);
                    aside.Add((target, backup));
                }
                foreach (var (_, path) in plan.Writes)
                {
                    string target = PackFiles.Under(root, path);
                    Directory.CreateDirectory(Path.GetDirectoryName(target)!);
                    File.Move(PackFiles.Under(staged, path), target);
                    placed.Add(target);
                }
            }
            catch
            {
                foreach (string target in placed) TryDelete(target);
                foreach (var (target, backup) in aside)
                {
                    try { File.Move(backup, target); }
                    catch (Exception error) { log.LogError($"could not restore {target}: {error.Message}"); }
                }
                throw;
            }
            // A replaced file still in use (only possible for the loader's own files on Windows)
            // cannot be deleted yet; the next start removes it.
            var leftovers = aside.Where(a => !TryDelete(a.Backup)).Select(a => a.Backup).ToList();
            if (leftovers.Count > 0)
                File.WriteAllLines(Path.Combine(stage, PackFiles.LeftoverFile),
                    leftovers.Select(l => l.Substring(root.Length).TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar).Replace(Path.DirectorySeparatorChar, '/')));
            result = $"updated {plan.Version} {plan.Writes.Count} {plan.Deletes.Count}";
            log.LogInfo($"Pack updated to {plan.Version}: {plan.Writes.Count} file(s) written, {plan.Deletes.Count} removed");
        }
        catch (Exception error)
        {
            result = "failed " + error.Message.Replace('\n', ' ');
            log.LogError("Pack update not installed; the Pack is unchanged: " + error.Message);
        }
        File.WriteAllText(Path.Combine(stage, PackFiles.ResultFile), result + "\n");
        TryDelete(planFile);
        try { if (Directory.Exists(staged)) Directory.Delete(staged, true); }
        catch (Exception error) { log.LogWarning("could not remove the staging folder: " + error.Message); }
    }

    private static void RemoveLeftovers(string root, string stage, ManualLogSource log)
    {
        string list = Path.Combine(stage, PackFiles.LeftoverFile);
        if (!File.Exists(list)) return;
        var remaining = new List<string>();
        foreach (string path in File.ReadAllLines(list).Where(l => l.Length > 0))
        {
            if (!path.EndsWith(PackFiles.BackupSuffix, StringComparison.Ordinal)) continue;
            string file = PackFiles.Under(root, path);
            if (File.Exists(file) && !TryDelete(file)) remaining.Add(path);
        }
        if (remaining.Count > 0) File.WriteAllLines(list, remaining);
        else File.Delete(list);
        log.LogInfo($"Removed replaced Pack files from the last update; {remaining.Count} still in use");
    }

    private static bool TryDelete(string file)
    {
        try
        {
            if (File.Exists(file)) File.Delete(file);
            return true;
        }
        catch (IOException) { return false; }
        catch (UnauthorizedAccessException) { return false; }
    }
}
