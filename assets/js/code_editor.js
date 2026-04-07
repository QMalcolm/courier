import {EditorView, basicSetup} from "codemirror"
import {yaml} from "@codemirror/lang-yaml"

const CodeEditor = {
  mounted() {
    const textarea = this.el
    const wrapper = document.getElementById("recipe-source-editor")
    wrapper.className = "cm-editor-wrapper border border-zinc-300 rounded-lg overflow-hidden"

    this.view = new EditorView({
      doc: textarea.value,
      extensions: [
        basicSetup,
        yaml(),
        EditorView.theme({
          "&": {fontSize: "13px", height: "480px"},
          ".cm-scroller": {overflow: "auto", fontFamily: "ui-monospace, monospace"},
        }),
        EditorView.updateListener.of(update => {
          if (update.docChanged) {
            textarea.value = this.view.state.doc.toString()
            textarea.dispatchEvent(new Event("input", {bubbles: true}))
          }
        }),
      ],
      parent: wrapper,
    })
  },

  updated() {
    const newValue = this.el.value
    if (newValue !== this.view.state.doc.toString()) {
      this.view.dispatch({
        changes: {from: 0, to: this.view.state.doc.length, insert: newValue},
      })
    }
  },

  destroyed() {
    this.view.destroy()
  },
}

export default CodeEditor
