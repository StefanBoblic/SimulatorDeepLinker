import { Action, ActionPanel, Color, Icon, Keyboard, List, Toast, getPreferenceValues, showToast } from "@raycast/api";
import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { promisify } from "node:util";
import { useEffect, useMemo, useState } from "react";

const executeFile = promisify(execFile);

type Preferences = {
  storageFile: string;
  cliPath: string;
  defaultEnvironment?: string;
  platform: "ios" | "ios-device" | "android";
  target: string;
  bundleIdentifier?: string;
  androidPackage?: string;
};

type DeepLink = {
  id: string;
  title: string;
  urlString: string;
  group?: string;
  tags?: string[];
  isFavorite?: boolean;
};

type LinkEnvironment = {
  id: string;
  name: string;
  variables: Record<string, string>;
  isBuiltIn?: boolean;
};

const builtInEnvironments: LinkEnvironment[] = [
  { id: "00000000-0000-0000-0000-000000000001", name: "Development", variables: {}, isBuiltIn: true },
  { id: "00000000-0000-0000-0000-000000000002", name: "Production", variables: {}, isBuiltIn: true },
];

export default function SearchDeepLinks() {
  const preferences = getPreferenceValues<Preferences>();
  const [links, setLinks] = useState<DeepLink[]>([]);
  const [environments, setEnvironments] = useState<LinkEnvironment[]>(builtInEnvironments);
  const [selectedEnvironment, setSelectedEnvironment] = useState(preferences.defaultEnvironment || "Development");
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string>();

  async function load() {
    setIsLoading(true);
    setError(undefined);
    try {
      const linkData = await readFile(preferences.storageFile, "utf8");
      const decodedLinks = JSON.parse(linkData) as DeepLink[];
      const environmentPath = path.join(path.dirname(preferences.storageFile), "environments.json");
      const decodedEnvironments = await readFile(environmentPath, "utf8")
        .then((value) => JSON.parse(value) as LinkEnvironment[])
        .catch(() => builtInEnvironments);

      setLinks(decodedLinks);
      setEnvironments(decodedEnvironments);
      if (!decodedEnvironments.some((environment) => environment.name === selectedEnvironment)) {
        setSelectedEnvironment(decodedEnvironments[0]?.name ?? "Development");
      }
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : String(loadError));
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, [preferences.storageFile]);

  const sortedLinks = useMemo(
    () => [...links].sort((left, right) => Number(Boolean(right.isFavorite)) - Number(Boolean(left.isFavorite))),
    [links],
  );

  async function openLink(link: DeepLink) {
    const toast = await showToast({ style: Toast.Style.Animated, title: `Opening ${link.title}` });
    try {
      await executeFile(preferences.cliPath, cliArguments("open", link.id));
      toast.style = Toast.Style.Success;
      toast.title = "Deep Link Opened";
      toast.message = resolve(link.urlString, selectedEnvironment, environments);
    } catch (openError) {
      toast.style = Toast.Style.Failure;
      toast.title = "Could Not Open Deep Link";
      toast.message = commandError(openError);
    }
  }

  function cliArguments(command: "open" | "resolve", linkID: string): string[] {
    const argumentsList = [command, linkID, "--storage", preferences.storageFile];
    if (selectedEnvironment) argumentsList.push("--environment", selectedEnvironment);
    if (command === "open") {
      argumentsList.push("--platform", preferences.platform, "--target", preferences.target);
      if (preferences.bundleIdentifier) argumentsList.push("--bundle-id", preferences.bundleIdentifier);
      if (preferences.androidPackage) argumentsList.push("--package", preferences.androidPackage);
    }
    return argumentsList;
  }

  return (
    <List
      isLoading={isLoading}
      searchBarPlaceholder="Search by name, URL, group, or tag"
      searchBarAccessory={
        <List.Dropdown tooltip="Environment" value={selectedEnvironment} onChange={setSelectedEnvironment}>
          {environments.map((environment) => (
            <List.Dropdown.Item key={environment.id} title={environment.name} value={environment.name} />
          ))}
        </List.Dropdown>
      }
    >
      {error ? (
        <List.EmptyView icon={Icon.ExclamationMark} title="Could Not Read Storage" description={error} />
      ) : (
        sortedLinks.map((link) => {
          const resolvedURL = resolve(link.urlString, selectedEnvironment, environments);
          return (
            <List.Item
              key={link.id}
              icon={link.isFavorite ? { source: Icon.Star, tintColor: Color.Yellow } : Icon.Link}
              title={link.title}
              subtitle={resolvedURL}
              keywords={[link.urlString, link.group ?? "", ...(link.tags ?? [])]}
              accessories={[
                ...(link.group ? [{ tag: link.group }] : []),
                ...(link.tags ?? []).slice(0, 2).map((tag) => ({ tag })),
              ]}
              actions={
                <ActionPanel>
                  <Action title="Open Deep Link" icon={Icon.Play} onAction={() => openLink(link)} />
                  <Action.CopyToClipboard title="Copy Resolved URL" content={resolvedURL} />
                  <Action.CopyToClipboard
                    title="Copy Template URL"
                    content={link.urlString}
                    shortcut={Keyboard.Shortcut.Common.Copy}
                  />
                  <Action
                    title="Refresh"
                    icon={Icon.ArrowClockwise}
                    onAction={load}
                    shortcut={Keyboard.Shortcut.Common.Refresh}
                  />
                  <Action.ShowInFinder path={preferences.storageFile} />
                </ActionPanel>
              }
            />
          );
        })
      )}
    </List>
  );
}

function resolve(source: string, environmentName: string, environments: LinkEnvironment[]): string {
  const environment = environments.find((candidate) => candidate.name === environmentName);
  return Object.entries(environment?.variables ?? {}).reduce(
    (value, [key, replacement]) => value.replaceAll(`{{${key}}}`, replacement).replaceAll(`\${${key}}`, replacement),
    source,
  );
}

function commandError(error: unknown): string {
  if (typeof error === "object" && error && "stderr" in error) {
    return String((error as { stderr?: string }).stderr || "Command failed").trim();
  }
  return error instanceof Error ? error.message : String(error);
}
