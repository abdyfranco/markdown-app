enum MarkdownGuide {
    static let text = """
    # Markdown Guide

    Markdown is plain text with a few simple marks. Edit on the left and the result appears on the right.

    ## Text

    *Italic* or _italic_ · **Bold** · ***Bold italic*** · ~~Strikethrough~~ · `inline code`

    Line breaks need two trailing spaces or a blank line between paragraphs.

    ## Headings

    ```
    # Heading 1
    ## Heading 2
    ### Heading 3
    ```

    ## Lists

    - Bullets start with `-`, `*` or `+`
    - Press **Return** to continue a list, and again to end it
        - Press **Tab** to indent

    1. Numbered lists count for you
    2. Like this

    - [x] Checklists use `- [ ]`
    - [ ] And `- [x]` when done

    ## Links and images

    [A link](https://commonmark.org) · <https://example.com>

    ```
    ![Alt text](image.png)
    ```

    ## Quotes

    > Quotes start with a greater-than sign.

    ## Code

    ```swift
    let greeting = "Hello, Markdown"
    print(greeting)
    ```

    ## Tables

    | Left | Center | Right |
    |:-----|:------:|------:|
    | One  |  Two   | Three |
    | 1    |   2    |     3 |

    ## Dividers

    Three dashes make a divider:

    ---

    ## Shortcuts

    | Action | Shortcut |
    |:--|:--|
    | Editor · Split · Preview | ⌘1 · ⌘2 · ⌘3 |
    | Bold · Italic · Link | ⌘B · ⌘I · ⌘K |
    | Heading 1–3 | ⌥⌘1 – ⌥⌘3 |
    | Checklist | ⇧⌘L |
    | Bigger · Smaller | ⌘+ · ⌘− |
    """
}
