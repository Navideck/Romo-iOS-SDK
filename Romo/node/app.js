var fs = require('fs')
  , http = require('http');

var SCRIPT_DIR = process.env.SCRIPT_DIR || (__dirname + '/../Content/Character Scripts/')
  , PORT = process.env.PORT || 8050;

var scripts = fs.readdirSync(SCRIPT_DIR).filter(function (name) {
  return name.match(/\.json$/);
});

console.log(scripts);

var server = http.createServer(function (req, res) {
  if (req.method === 'GET' && req.url === '/scripts') {
    var content = JSON.stringify(scripts);

    res.writeHead(200, {
      'Content-Length': content.length,
      'Content-Type': 'application/json'
    });

    return res.end(content);
  }

  if (req.method === 'GET' && req.url.match(/\/scripts\/(.+)/)) {
    var match = req.url.match(/\/scripts\/(.+)/);

    return fs.readFile(SCRIPT_DIR + match[1], function (err, content) {
      if (err && err.errno === 34) {
        res.writeHead(404, {});
        return res.end('Not found');
      }

      if (err) {
        console.error(err);
        res.writeHead(500, {});
        return res.end('Internal Error');
      }

      res.writeHead(200, {
        'Content-Length': content.length,
        'Content-Type': 'application/json'
      });

      return res.end(content);
    });
  }


  res.writeHead(404, {});
  res.end('Not found');
});

server.listen(PORT);
console.log('Listening on port:', PORT);
