## Communication style

- The user is non-technical. Every explanation, summary, or status update
  addressed to them must be written in plain, non-technical language: no
  jargon, tool/file names, code, or acronyms unless a plain-English gloss
  comes with it. Explain what something means for the product or the
  user's decision, not how it works internally.
- This applies to conversational replies. Code, commit messages, and
  in-repo documentation (README, ADRs, tickets) can stay technical — those
  are for whoever maintains the code later, not for reading in chat.

## Context economy rules

- When delegating research or investigation to a subagent (Task/Agent tool), 
  instruct it explicitly to write its full findings to a file under the 
  project's scratch/research directory, and to return to you only a short 
  summary (a few sentences: key conclusion, any decision it implies, and the 
  file path) — never the full document inline in its response.
- Before reading a file you expect to be large (existing research docs, 
  logs, generated reports), check its size first or use Grep to find the 
  relevant section, then Read with offset/limit for just that range — do 
  not Read the whole file unless it's small or you genuinely need all of it.
- When resuming a task after a subagent finishes, don't re-read its full 
  output file unless you need details beyond what its summary already gave 
  you.