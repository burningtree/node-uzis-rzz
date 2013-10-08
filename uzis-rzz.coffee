
iconv = require 'iconv-lite'
request = require 'request'
async = require 'async'
$ = require 'cheerio'
crypto = require 'crypto'
fs = require 'fs'
jsoncsv = require 'jsoncsv'

output = []
krajOutput = {}
krajCount = {}

concurrency = 1

indexUrl = 'https://snzr.uzis.cz/viewzz/RZZHledat1.htm'
listUrl = 'https://snzr.uzis.cz/viewzz/lb/RZZSeznam.pl?KRAJ=@KRAJ@&ORP=V%8AE&OBEC=V%8AE&TYP=V%8AE&DRZAR=V%8AE&OBOR=V%8AE&ZRIZOVATEL=V%8AE&NAZEV=V%8AE&Hledat=Hledat&WAIT_PAGE=ON'

sha1 = (str) =>
  crypto.createHash('sha1').update(str).digest('hex')

trim = (str) =>
  str.replace /^\s+|\s+$/g, ''

encodeURIString = (str) =>
  map = { ' ': '+', 'ň': '%F2', 'ý': '%FD', 'ř': '%F8', 'č': '%E8', 'í': '%ED', 'á': '%E1', 'é': '%E9', 'Ú': '%DA' }
  for k,v of map
    str = str.replace k, v
  return str

fetch = (url, back, cache=true) =>

  backFetch = (html) =>
    back $.load(iconv.decode(html, 'cp1250'))
    
  cacheDir = './cache'
  cacheFile = cacheDir + '/' + sha1(url)

  if cache && fs.existsSync(cacheFile) && fs.statSync(cacheFile).size > 0
    fs.readFile cacheFile, (err,data) =>
      backFetch data

  else
    request { url: url, strictSSL: false, encoding: 'binary' }, (err, resp, html) =>
      if cache
        fs.writeFile cacheFile, html, { encoding: 'binary' }

      backFetch html

processLine = (data, meta, long=false) =>
  #console.log meta
  $('table[cellpadding="1"] tr', $(data)).each (i, item) =>

    pre =
      kraj: meta.kraj
      region: meta.region
      catId: meta.category.match(/^(\d{3})\s*.+$/)[1]
      catName: meta.category.match(/^\d{3}\s*(.+)$/)[1]
      name: trim($('td:nth-child(1)', $(item)).text())
      address: trim($('td:nth-child(2)', $(item)).text())

    if pre.name != 'Název' && pre.name != ''
      if long
        pre.fullName = trim($('td:nth-child(3)', $(item)).text())
        pre.phone = trim($('td:nth-child(4)', $(item)).text())
        pre.detas = trim($('td:nth-child(6)', $(item)).text())
        pre.id = $('td:nth-child(5) a', $(item)).attr('onclick').match(/"RZZDetail\.pl\?(\d+)=Detail/)[1]

      else
        pre.fullName = ''
        pre.phone = trim($('td:nth-child(3)', $(item)).text())
        pre.detas = trim($('td:nth-child(5)', $(item)).text())
        pre.id = $('td:nth-child(4) a', $(item)).attr('onclick').match(/"RZZDetail\.pl\?(\d+)=Detail/)[1]

      krajOutput[meta.kraj].push pre
      #console.log pre

processKraj = (task, callback) =>
  console.log 'Spoustim zpracovani `'+task.kraj+'` .. '
  #console.log task.url

  krajOutput[task.kraj] = []

  fetch task.url, ($) =>
    category = null; region = null; totalCount = 0

    $('body > table').each (i, item) =>
      width = $(item).attr('width')
      switch width
        when '793'
          krajCount[task.kraj] = $(item).text().match(/Počet vybraných zařízení je:\s*(\d+)/)[1]
        when '643'
          category = $('font', $(item)).text()
        when '811'
          region = $('font', $(item)).text().match(/ORP:\s+(.+)/)[1]
        when '800'
          processLine item, { kraj: task.kraj, region: region, category: category }
        when '1026'
          processLine item, { kraj: task.kraj, region: region, category: category }, true
        #else
        #  console.log width
  
    if krajOutput[task.kraj].length != parseInt(krajCount[task.kraj])
      console.log 'Nesedi pocet zaznamu!! parsovano: '+krajOutput[task.kraj].length+' deklarovano: '+krajCount[task.kraj]
      process.exit(1)

    output = output.concat krajOutput[task.kraj]
    console.log 'Kraj `'+task.kraj+'` hotovy. Pridano '+krajOutput[task.kraj].length+' zaznamu. Celkem zaznamu: '+output.length
    callback()

q = async.queue processKraj, concurrency
q.drain = =>

  # mame hotovo, vygenerujeme soubory
  fnBase = 'uzis-rzz-'+new Date().toISOString().replace(/:\d+\.\d+Z$/, '').replace(':','')
  fn = csv: fnBase+'.csv', json: fnBase+'.json'

  console.log 'Parsovani hotovo.'
  console.log 'Generuji soubor `'+fn.json+'` ..'
  fs.writeFileSync fn.json, JSON.stringify(output)

  console.log 'Generuji soubor `'+fn.csv+'` ..'
  cols = [ 'kraj', 'region', 'catId', 'catName', 'id', 'name', 'fullName', 'address', 'phone', 'detas' ]
  csvOutput = cols.join(',')+"\r\n"

  for oi, item of output
    line = []
    for ci, c of cols
      line.push '"'+item[c].replace('"', '\\"')+'"'

    csvOutput = csvOutput + line.join(',') + "\n"

  fs.writeFileSync fn.csv, csvOutput

  console.log 'Hotovo.'

# -------------------
# START
# -------------------

console.log 'Stahuji index ..'
fetch indexUrl, ($) =>
  $('select#kraj option').each (i, item) =>
    kraj = $(item).attr('value')
    url = listUrl.replace '@KRAJ@', encodeURIString(kraj)

    if i == 0
      q.push { kraj: kraj, url: url }

