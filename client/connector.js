// Generated by CoffeeScript 1.10.0
(function() {
  var io, ref;

  io = (ref = this.io) != null ? ref : require('socket.io-client');

  (typeof exports !== "undefined" && exports !== null ? exports : this.o).Connector = function(params) {
    var connector, delay, dis, failed, router, wrap;
    router = params.router;
    connector = io(params.address, {
      transports: params.transports,
      query: {
        _version: params.version,
        _mobile: params.mobile ? '1' : '0'
      }
    });
    router.send = function() {
      return connector.emit('request', Array.prototype.slice.call(arguments));
    };
    ['connect', 'request'].forEach(function(ev) {
      return connector.on(ev, function(data) {
        return router[ev].apply(router, data);
      });
    });
    connector.on('request', function(data) {
      return connector.emit('request_receive');
    });
    connector.on('session', function(id) {
      return connector.io.opts.query._session = id;
    });
    connector.on('version', function() {
      return params.version_callback();
    });
    delay = 0;
    connector.on('error:duplicate', function() {
      delay = 15;
      return router.login_duplicate();
    });
    wrap = function(fn) {
      if (delay === 0) {
        return fn();
      } else {
        return setTimeout(fn, delay * 1000);
      }
    };
    dis = function() {
      return wrap(function() {
        return router.disconnect();
      });
    };
    failed = function() {
      return wrap(function() {
        return router.connect_failed();
      });
    };
    connector.on('connect_error', failed);
    connector.on('connect_timeout', failed);
    connector.on('error', failed);
    connector.on('disconnect', dis);
    ['reconnect_attempt', 'reconnecting'].forEach(function(ev) {
      return connector.on(ev, function() {
        return console.info(ev);
      });
    });
    return connector;
  };

}).call(this);
