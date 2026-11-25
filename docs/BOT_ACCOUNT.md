# Bot account setup

Claude contributes as **BryceAIRich**; the rules are in
[`CLAUDE.md`](../CLAUDE.md#claudes-github-identity). Once per clone:

1. Log the bot in to `gh` next to your own account, then `gh auth switch` back to yourself. Its
   token needs `repo`, `project`, `read:org` and `workflow` (for `.github/workflows/`).
2. Invite the bot to the repo with write access, and accept as the bot.
3. Add its remote and credentials. Nothing here is committed, and the token stays in `gh`:

   ```bash
   git config --local claude.botUser BryceAIRich
   git remote add bot https://BryceAIRich@github.com/BryceARich/nhl_scoreboard.git
   git config --local --add 'credential.https://BryceAIRich@github.com.helper' ''
   git config --local --add 'credential.https://BryceAIRich@github.com.helper' \
     '!f() { test "$1" = get && echo username=BryceAIRich && echo "password=$(gh auth token --user BryceAIRich)"; }; f'
   ```

Check it: `GH_TOKEN=$(gh auth token --user BryceAIRich) gh api repos/BryceARich/nhl_scoreboard -q .permissions.push`
should print `true`.
