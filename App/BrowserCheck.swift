import Foundation

enum BrowserCheck {
    static let html = #"""
    <!doctype html><html lang="en"><meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>XENPHIA Glass browser check</title>
    <style>
    :root{color-scheme:dark}body{font:18px system-ui;margin:0;padding:24px;background:#07171e;color:#e5faff;line-height:1.5;max-width:720px}h1{color:#6ce9ef;font-size:30px}button,input{font:inherit;padding:12px;margin:6px 0;border:1px solid #47838d;border-radius:10px;background:#102d36;color:inherit}button{display:block}input{max-width:90%}output{display:block;min-height:30px;color:#86edd8}a{color:#6ce9ef}.note{color:#b0c8d1}
    </style><h1>XENPHIA Glass browser check</h1>
    <p class="note">This page is included with the app. The checks below need no account. They do not automatically report success to anyone.</p>
    <h2>1. Typing</h2><label>Type here <input placeholder="Hello XENPHIA Glass" autocomplete="off"></label>
    <h2>2. Website dialogs</h2>
    <button onclick="alert('This is a built-in test alert.');document.querySelector('#result').textContent='Alert closed.'">Test alert</button>
    <button onclick="document.querySelector('#result').textContent=confirm('Accept this built-in test?')?'Confirm accepted.':'Confirm cancelled.'">Test confirm</button>
    <button onclick="const answer=prompt('Type a test word.','cyan');document.querySelector('#result').textContent=answer===null?'Prompt cancelled.':'Prompt returned: '+answer">Test text prompt</button><output id="result"></output>
    <h2>3. Download</h2><p>Tap this button, then open Downloads in the browser toolbar. Share the completed text file and choose Save to Files.</p>
    <button onclick="const blob=new Blob(['XENPHIA Glass download check passed: a text file was created.\n'],{type:'text/plain'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download='Cyan-Glass-Test.txt';document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),60000)">Download test text file</button>
    <h2>4. Find on page</h2><p>Use the browser menu, choose Find on page and search for this exact phrase: <strong>cyan crystal</strong>.</p>
    <p>Second match: cyan crystal. Next and Previous should move between the matches.</p>
    <h2>5. Online navigation</h2><p>These links require internet:</p>
    <p><a href="https://example.com/">Open Example.com in this tab</a></p>
    <p><a href="https://example.com/" target="_blank" rel="noopener">Open Example.com in a new tab</a></p>
    <p class="note">After opening a site, try Back, Forward, Reload, Bookmark and Share. Test a private tab separately and confirm its visited pages do not appear in History. Keep a screenshot of any app error.</p>
    </html>
    """#
}
