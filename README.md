## GitHooks

### Setup information:

1. Move the files to .git/hooks/* - remove the .rb extensions to make the files executable. template file can remain as a .txt file.
2. Run the following commands:
```
git config commit.template .git/hooks/commit_template.txt
git config user.name "<your-user-name>"
chmod +x .git/hooks/*
```
