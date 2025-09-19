# Lade automatisch gespeicherte Einstellungen.
config.load_autoconfig()

# Behalte die Sitzung beim Schließen immer bei.
c.auto_save.session = True

# Standardzoomlevel ändern
c.zoom.default = '130%'

# ---- Scribe: Copy Transcript (Plaintext)
def _scribe_copy_text_js():
    return (
        "(()=>{var h=location.hostname;if(!(/\\.appblit\\.com$/.test(h)||h==='appblit.com'))return false;"
        "function grab(){var sel=document.querySelectorAll('.header:not(.notpro),.p:not(.notpro,.upgrade)');"
        "var title=(document.title||'').replace(/^Scribe - /,'');"
        "var out=title?title+'\\n\\n':'';"
        "sel.forEach(function(e){if(e.classList.contains('header')){out+=e.textContent.trim()+'\\n\\n';}"
        "else{out+=e.innerText.trim()+'\\n\\n';}});return out.trim();}"
        "var txt=grab();"
        "try{var ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.focus();ta.select();"
        "var ok=document.execCommand('copy');document.body.removeChild(ta);if(ok){return true;}}catch(e){}"
        "try{navigator.clipboard.writeText(txt).then(()=>{},()=>{});}catch(e){}"
        "alert('Copy (Ctrl+C / Enter)');prompt('Transcript:',txt);return false;})()"
    )

config.bind(',st', "jseval --quiet " + _scribe_copy_text_js())


