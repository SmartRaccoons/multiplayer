// Generated by CoffeeScript 2.3.2
(function() {
  var View, touch, update_ev, view_id,
    boundMethodCheck = function(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new Error('Bound instance method accessed before binding'); } };

  view_id = 0;

  update_ev = 'options_update';

  touch = ('ontouchstart' in window) || (navigator.MaxTouchPoints > 0) || (navigator.msMaxTouchPoints > 0);

  this.o.View = View = (function() {
    class View extends SimpleEvent {
      constructor(options) {
        super();
        this.option_bind_el = this.option_bind_el.bind(this);
        this.option_bind_el_attr = this.option_bind_el_attr.bind(this);
        this.options = _.extend(_.cloneDeep(this.options_default), options);
        view_id++;
        this._id = view_id;
        this.$el = $(`<${this.el}>`);
        if (this.className) {
          this.$el.addClass(this.className);
        }
        this.__events_delegate();
        this.__events_binded_el = [];
        this._options_bind = Object.keys(this.options_bind).reduce((acc, v) => {
          return acc.concat({
            events: v.split(','),
            fn: this.options_bind[v].bind(this)
          });
        }, []);
        this;
      }

      __events_delegate() {
        var el, fn, k, m, ref, results, v;
        if (!this.events) {
          return;
        }
        ref = this.events;
        results = [];
        for (k in ref) {
          v = ref[k];
          m = k.match(/^(\S+)\s*(.*)$/);
          fn = typeof v !== 'string' ? _.bind(v, this) : ((v) => {
            return () => {
              return this[v]();
            };
          })(v);
          el = this.__selector_parse(m[2], true);
          results.push(m[1].split(',').forEach((event) => {
            var ev, pr;
            [ev, pr] = event.split(':');
            if (pr === 'nt' && touch) {
              return;
            }
            if (pr === 't' && !touch) {
              return;
            }
            if (ev === 'click' && touch) {
              ev = 'touchstart';
            }
            return this.$el.on(`${ev}.delegateEvents${this._id}`, el, fn);
          }));
        }
        return results;
      }

      __events_undelegate() {
        return this.$el.off('.delegateEvents' + this._id);
      }

      options_update(options, force = false) {
        var k, updated, v;
        updated = [];
        for (k in options) {
          v = options[k];
          if (force || this.options[k] !== v) {
            this.options[k] = v;
            updated.push(k);
          }
        }
        if (updated.length === 0) {
          return;
        }
        this._options_bind.filter(function(v) {
          return updated.filter(function(up) {
            return v.events.indexOf(up) >= 0;
          }).length > 0;
        }).forEach(function(v) {
          return v.fn();
        });
        updated.forEach((option) => {
          return this.trigger(`${update_ev}:${option}`);
        });
        return this.trigger(update_ev);
      }

      options_update_bind(option, exec) {
        return this.bind(`${update_ev}:${option}`, exec);
      }

      _option_get_from_str(str) {
        var res;
        res = str.trim().match(/^(?:\&|\&amp;)\=([\w]*)$/);
        if (res) {
          return res[1];
        }
        return null;
      }

      option_bind_el(el) {
        var attributes, option, ref;
        boundMethodCheck(this, View);
        attributes = $(el)[0].attributes;
        (function() {
          var results = [];
          for (var j = 0, ref = attributes.length; 0 <= ref ? j < ref : j > ref; 0 <= ref ? j++ : j--){ results.push(j); }
          return results;
        }).apply(this).forEach((i) => {
          var option;
          option = this._option_get_from_str(attributes[i].value);
          if (!option) {
            return;
          }
          return this.option_bind_el_attr(el, attributes[i].name, option)();
        });
        option = this._option_get_from_str($(el).html());
        if (option) {
          return this.option_bind_el_attr(el, 'html', option)();
        }
      }

      option_bind_el_attr(el, attr, option) {
        var exec, val_get;
        boundMethodCheck(this, View);
        val_get = () => {
          return this.options[option];
        };
        exec = () => {
          var val;
          val = val_get();
          if (attr === 'html') {
            return $(el)[attr](val);
          }
          if (val === null || val === false) {
            return $(el).removeAttr(attr);
          }
          return $(el).attr(attr, val);
        };
        this.bind(`${update_ev}:${option}`, exec);
        this.__events_binded_el.push(`${update_ev}:${option}`);
        return exec;
      }

      render() {
        if (!this.template) {
          return this;
        }
        (() => {
          var ev, results;
          results = [];
          while (ev = this.__events_binded_el.shift()) {
            results.push(this.unbind(ev));
          }
          return results;
        })();
        this._options_bind.forEach(function(v) {
          return v.fn();
        });
        this.$el.html(_.template(this.template)({
          self: this
        }));
        this.$el.find('[class]').forEach((el) => {
          return $(el).attr('class', this.__selector_parse($(el).attr('class')));
        });
        (() => {
          var attr, option, ref, results;
          ref = this.options_bind_el_self;
          results = [];
          for (attr in ref) {
            option = ref[attr];
            results.push(this.option_bind_el_attr(this.$el, attr, option)());
          }
          return results;
        })();
        this.$el.find('*').forEach((el) => {
          return this.option_bind_el(el);
        });
        return this;
      }

      subview_append(view, events = []) {
        if (!this.__subview) {
          this.__subview = [];
        }
        this.__subview.push(view);
        this.subview_events_pass(events, view, this);
        return view;
      }

      subview_events_pass(events, view, parent = this) {
        return events.forEach((ev) => {
          return view.bind(ev, (args) => {
            return parent.trigger(ev, args);
          });
        });
      }

      subview_remove() {
        var results, view;
        if (this.__subview) {
          results = [];
          while (view = this.__subview.shift()) {
            results.push(view.remove());
          }
          return results;
        }
      }

      hide() {
        this.$el.addClass('hidden');
        return this.trigger('hide');
      }

      show() {
        this.$el.removeClass('hidden');
        return this.trigger('show');
      }

      remove() {
        this.subview_remove();
        super.remove(...arguments);
        this.__events_undelegate();
        return this.$el.remove();
      }

      __selector_parse(s, point = false) {
        return s.replace('&-', `${(point ? '.' : '')}${this.className}-`);
      }

      $(selector) {
        return this.$el.find(this.__selector_parse(selector, true));
      }

    };

    View.prototype.className = null;

    View.prototype.el = 'div';

    View.prototype.template = '';

    View.prototype.events = {};

    View.prototype.options_bind = {};

    View.prototype.options_bind_el_self = {};

    return View;

  }).call(this);

}).call(this);
