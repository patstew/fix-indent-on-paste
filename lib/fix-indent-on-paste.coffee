path = require 'path'
{pick} = require 'underscore-plus'

NonWhitespaceRegExp = /\S/
TabSpaceRegExp = /^[\t ]*$/
StartsWithNewlineRegExp = /^(\r\n|\n)/
LineRegExp = /[^\r\n]+/

module.exports =

  initialize: (state) ->
    # console.log("Monkey patching selection")

    atom.commands.add 'atom-text-editor',
      'fix-indent-on-paste:paste_raw': (options={}) ->
        options.raw = true
        atom.workspace.getActiveTextEditor().pasteText(options)

    # Access a bundled package
    tabs = atom.packages.getLoadedPackage('tabs')
    sourcePath = path.resolve(tabs.path, '../../src')
    Selection = require "#{sourcePath}/selection"

    Selection::insertText = (text, options={}) ->
      oldBufferRange = @getBufferRange()
      wasReversed = @isReversed()
      @clear(options)

      autoIndentFirstLine = false
      multiLine = false

      if options.autoIndent and not options.raw?
        lines = text.split('\n')
        multiLine = lines.length > 1
        startsWithNewLine = StartsWithNewlineRegExp.test(text)

        if multiLine
          precedingText = @editor.getTextInRange([[oldBufferRange.start.row, 0], oldBufferRange.start])
          indentAdjustment = @editor.indentLevelForLine(precedingText)

          if options.autoDecreaseIndent
            indentAdjustment -= @editor.languageMode.suggestedIndentForBufferRow(oldBufferRange.start.row)
            if startsWithNewLine
              indentAdjustment += @editor.languageMode.suggestedIndentForLineAtBufferRow(oldBufferRange.start.row + 1, line[1])
            else
              firstLine = precedingText + lines[0]
              indentAdjustment += @editor.languageMode.suggestedIndentForLineAtBufferRow(oldBufferRange.start.row, firstLine)
              autoIndentFirstLine = true
              desiredIndentLevel = indentAdjustment

          if startsWithNewLine
            firstNonNewline = text.match(LineRegExp)
            if firstNonNewline?
              indentAdjustment -= @editor.indentLevelForLine(firstNonNewline[0])
          else
            if options.indentBasis?
              indentAdjustment -= options.indentBasis

          # console.log("Indent", @editor.indentLevelForLine(firstNonNewline[0]), indentAdjustment, desiredIndentLevel, @editor.indentLevelForLine(precedingText), options.indentBasis)

          firstLine = lines.shift()
          @adjustIndent(lines, indentAdjustment)
          lines.unshift(firstLine)

          text = lines.join('\n')

      newBufferRange = @editor.buffer.setTextInRange(oldBufferRange, text, pick(options, 'undo', 'normalizeLineEndings'))

      if options.select
        @setBufferRange(newBufferRange, reversed: wasReversed)
      else
        @cursor.setBufferPosition(newBufferRange.end) if wasReversed

      if options.raw?
      else if options.autoIndentNewline and text is '\n'
        @editor.autoIndentBufferRow(newBufferRange.end.row, preserveLeadingWhitespace: true, skipBlankLines: false)
      else if options.autoDecreaseIndent and NonWhitespaceRegExp.test(text) and not multiLine
        @editor.autoDecreaseIndentForBufferRow(newBufferRange.start.row)
      else if autoIndentFirstLine
        @editor.setIndentationForBufferRow(oldBufferRange.start.row, desiredIndentLevel)

      @autoscroll() if options.autoscroll ? @isLastSelection()

      newBufferRange
