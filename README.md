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

1. commit-msg - validates commit messages, fetches ticket information, allowing devs to only commit code for tickets which are in a certain status(ids) and are assigned to the dev who's committing the code.
2. pre-push - notify certain leads/managers when a commit contains certain kind of files, add a note on the ticket for which code is being pushed.
