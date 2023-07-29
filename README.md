# Learning x86_64 assembly (FASM edition)

I'll spare you the long exposition. Here's my code.

| :warning: I cannot guarantee the quality of each program. |
|-----------------------------------------------------------|

## Building

If you're on Nix, run the following commands.

```
git clone https://github.com/Supercolbat/learning-fasm
cd learning-fasm
nix-develop
```

If you aren't, then make sure you have `fasm` installed using your friendly local package manager.

## Projects

### Guess the number <kbd>IO</kbd> <kbd>Control flow</kbd>

The classic "Guess a number from 1 to 100" game. There are two versions:

1. `main.asm` is the complete version
3. `old.main-64bit-reg.asm` is incomplete and only uses 64-bit registers (which led to problems)

