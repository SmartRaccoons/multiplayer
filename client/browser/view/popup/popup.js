// Generated by CoffeeScript 2.3.2
(function() {
  var Popup;

  window.o.ViewPopup = Popup = (function() {
    class Popup extends window.o.View {
      constructor() {
        super(...arguments);
        if (this.options.parent) {
          this.$el.appendTo(this.options.parent);
        }
        this;
      }

      render() {
        super.render(...arguments);
        this.$container = $(this.$('div')[0]);
        return this;
      }

    };

    Popup.prototype.className = 'popup';

    Popup.prototype.template = "<div>\n   <% if (!('close' in self.options) || self.options.close){ %>\n    <button data-action='close' class='popup-close'>×</button>\n   <% } %>\n\n   <% if (self.options.head) { %>\n    <h1><%= typeof self.options.head === 'function' ? self.options.head({'self': self}) : self.options.head %></h1>\n   <% } %>\n\n   <div>\n     <%= typeof self.options.body === 'function' ? self.options.body({'self': self}) : self.options.body %>\n   </div>\n</div>";

    Popup.prototype.events = {
      'click button[data-action="close"]': function() {
        return this.remove();
      },
      'click [data-click]': function(e) {
        var el;
        el = $(e.target);
        this.trigger(el.attr('data-click'), el.attr('data-click-attr'));
        if (!el.is('[data-stay]')) {
          return this.remove();
        }
      }
    };

    return Popup;

  }).call(this);

}).call(this);
