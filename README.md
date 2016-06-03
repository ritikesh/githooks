## GitHooks

### Setup information:

1. Move the files to .git/hooks/* - remove the .rb extensions to make the files executable. template file can remain as a .txt file.
2. Run the following commands:
```
git config commit.template .git/hooks/commit_template.txt
git config user.name "<your-user-name>"
chmod +x .git/hooks/*
```

### The Hooks:

1. commit-msg - validates commit messages, fetching ticket information and allowing devs to only commit code for tickets in certain statuses and assigned to the dev.
2. pre-push - notify certain leads/managers when a commit contains certain kind of files, add a note on the ticket being pushed code for.