# ChatGPT

Package the skill and upload it to ChatGPT Skills:

```bash
python tools/package_skill.py --skill dotnet-upgrade
# or package every skill: python tools/package_skill.py --all
```

Upload `dist/dotnet-upgrade/skill.zip`. The included `agents/openai.yaml` provides display metadata.

The skill operates only on repository files and commands made available to the ChatGPT environment. Uploading the skill does not independently provide access to a local VS Code folder.
