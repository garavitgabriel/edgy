---
name: Bug report
about: A gesture misfired, didn't fire, or something else went wrong
labels: bug
---

**What happened**

**What you expected**

**Steps to reproduce**
1.
2.
3.

**Test Mode**
If a gesture was involved, turn on Test Mode in the popover and try again. What did the plate say?

**Your Mac**
- macOS version:
- Mac model:
- Trackpad (built-in, or an external one):
- Edgy version (About Edgy in the popover):
- Downloaded or built yourself:

**Log**
Run this right after it happens and paste the output (check it first for anything you'd rather not share):

```bash
/usr/bin/log show --last 10m --predicate 'subsystem == "com.garavit.edgy"' --info
```

**Touch trace (optional)**
For a misfire, a recorded trace lets us replay it in a test. See `scripts/record-traces.md`, then attach the JSON file.
