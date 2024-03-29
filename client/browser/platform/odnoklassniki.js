// Generated by CoffeeScript 2.7.0
(function() {
  var Odnoklassniki;

  window.o.PlatformOdnoklassniki = Odnoklassniki = (function() {
    class Odnoklassniki extends window.o.PlatformCommon {
      constructor() {
        var fn;
        super(...arguments);
        fn = (event, data) => {
          if (event === 'authenticate:error') {
            this.router.message(_l('Authorize.integrated login error'));
          }
          if (event === 'authenticate:success') {
            return this.router.unbind('request', fn);
          }
        };
        this.router.bind('request', fn);
        this.router.bind('connect', () => {
          return this.auth_send({
            odnoklassniki: window.location.href.split('?')[1],
            language: 'ru'
          });
        });
        this.router.bind(`request:buy:${this._name}`, ({service, transaction_id, price}) => {
          var params;
          params = this._buy_params({service, transaction_id, price});
          return FAPI.UI.showPayment(params.name, params.description, params.code, price, null, JSON.stringify({transaction_id}), 'ok', true);
        });
        this;
      }

      __init(callback) {
        var script;
        script = document.createElement('script');
        script.defer = 'defer';
        script.onload = function() {
          var rParams;
          rParams = FAPI.Util.getRequestParameters();
          FAPI.init(rParams["api_server"], rParams["apiconnection"], callback, function() {});
          return window.API_callback = function(method, result, data) {};
        };
        script.src = '//api.ok.ru/js/fapi5.js';
        return document.head.appendChild(script);
      }

      invite({text, params, selected_uids}) {
        return FAPI.UI.showInvite(text, params, selected_uids);
      }

      _buy_params() {
        throw 'buy params missing';
      }

    };

    Odnoklassniki.prototype._name = 'odnoklassniki';

    return Odnoklassniki;

  }).call(this);

}).call(this);
