# Turtl - Joplin Notes Converter

This is a pure Ruby script that will convert a JSON export from [Turtl](https://github.com/turtl/desktop) to 
the **RAW Joplin Export Directory** format suitable for import to [Joplin](https://github.com/laurent22/joplin)

It takes care of the following;
- Turtl Spaces become Joplin top-level Notebooks
- Turtl Boards are nested into their relevant top-level Notebook (ie. the Space they used to be nested under)
- Notes are attached to their correct notebook parent, whether that was a Space or a Board
- All tags are maintained
- Differing markdown is converted to the correct format
- Images attached to Turtl notes are preserved, and the images get embedded to the top of the corresponding Joplin note

What it can't do;
- Turtl Exports don't contain any timestamp information so note ordering will differ

---

## How to use

Just run the script, passing the file as an argument, eg. assuming your Turtl export is in the same directory as the script;
```
ruby turtl_joplin_converter.rb ./turtl-export.json
```

This will create a new directory called `raw` containing the **RAW Joplin Export Directory**.

To import this in Joplin, just go to File -> Import -> RAW - Joplin Export Directory
