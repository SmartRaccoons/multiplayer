// Generated by CoffeeScript 2.3.2
(function() {
  var CoinsBonus, CoinsBonusTimed;

  this.o.ViewCoinsBonus = CoinsBonus = (function() {
    class CoinsBonus extends this.o.View {
      get() {
        return this.trigger('get');
      }

    };

    CoinsBonus.prototype.className = 'coins-bonus';

    CoinsBonus.prototype.template = "<span> &=left </span>";

    CoinsBonus.prototype.options_default = {
      left: null
    };

    CoinsBonus.prototype.options_html = {
      left: function(v) {
        if (v === null) {
          return '';
        }
        if (v === 0) {
          return _l(`coinsbonus.${this.type}.get`, {
            coins: this.options.coins
          });
        }
      }
    };

    CoinsBonus.prototype.events = {
      'click button': 'get'
    };

    return CoinsBonus;

  }).call(this);

  this.o.ViewCoinsBonusTimed = CoinsBonusTimed = (function() {
    class CoinsBonusTimed extends CoinsBonus {
      remove() {
        clearTimeout(this._left_timeout);
        return super.remove(...arguments);
      }

    };

    CoinsBonusTimed.prototype.options_html = {
      left: function(v) {
        if (v && v > 0) {
          return _l(`coinsbonus.${this.type}.wait`, {
            time: [60 * 60, 60, 1].map((seconds) => {
              var units;
              if (seconds === 1) {
                return v;
              }
              units = Math.floor(v / seconds);
              v = v - units * seconds;
              return units;
            }).map(function(v) {
              if (v < 10) {
                return `0${v}`;
              } else {
                return v;
              }
            }).join(':')
          });
        }
        return CoinsBonus.prototype.options_html['left'].apply(this, [v]);
      }
    };

    CoinsBonusTimed.prototype.options_bind = {
      left: function() {
        clearTimeout(this._left_timeout);
        if (this.options.left && this.options.left > 0) {
          return this._left_timeout = setTimeout(() => {
            return this.options_update({
              left: this.options.left - 1
            });
          }, 1000);
        }
      }
    };

    return CoinsBonusTimed;

  }).call(this);

}).call(this);
