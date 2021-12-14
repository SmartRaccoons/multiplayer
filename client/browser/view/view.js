// Generated by CoffeeScript 2.5.1
(function() {
  var View, __body, touch, update_ev, view_id,
    boundMethodCheck = function(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new Error('Bound instance method accessed before binding'); } };

  view_id = 0;

  update_ev = 'options_update';

  touch = ('ontouchstart' in window) || (navigator.MaxTouchPoints > 0) || (navigator.msMaxTouchPoints > 0);

  __body = new SimpleEvent();

  $('body').on('click', function() {
    return __body.trigger('click');
  });

  if (touch) {
    $('body').addClass('touch');
  }

  this.o.View = View = (function() {
    class View extends SimpleEvent {
      constructor(options = {}) {
        super();
        this.option_bind_el = this.option_bind_el.bind(this);
        this.option_bind_el_attr = this.option_bind_el_attr.bind(this);
        this.__touch = touch;
        this.options = _.extend(_.cloneDeep(this.options_default), _.omit(options, ['el']));
        view_id++;
        this._id = view_id;
        this.$el = options.el || $(`<${this.el}>`);
        if (this.className) {
          this.$el.addClass(this.className);
        }
        this.__events_delegate();
        this.__events_binded_el = [];
        this.__options_bind = Object.keys(this.options_bind).sort().reduce((acc, v) => {
          return acc.concat({
            events: v.split(','),
            fn: this.options_bind[v].bind(this)
          });
        }, []);
        this;
      }

      options_default_over(options, options_default = Object.keys(this.options_default)) {
        return this.options_update(_.extend(_.cloneDeep(_.pick(this.options_default, options_default)), options));
      }

      __events_delegate() {
        if (!this.events) {
          return;
        }
        return Object.keys(this.events).sort().forEach((event_params) => {
          var el_str, event_match, fn, fn_binded;
          fn = this.events[event_params];
          event_match = event_params.match(/^(\S+)\s*(.*)$/);
          fn_binded = typeof fn !== 'string' ? _.bind(fn, this) : ((fn) => {
            return () => {
              return this[fn]();
            };
          })(fn);
          el_str = this.__selector_parse(event_match[2], true);
          if (el_str.substr(0, 1) === '&') {
            (function(self) {
              var el_str_parse, fn_binded_prev;
              el_str_parse = el_str.substr(1).split(' ');
              el_str = el_str_parse[1];
              fn_binded_prev = fn_binded;
              return fn_binded = function() {
                if (self.$el.is(el_str_parse[0])) {
                  return fn_binded_prev.apply(this, arguments);
                }
              };
            })(this);
          }
          return event_match[1].split(',').forEach((event) => {
            var ev, pr;
            [ev, pr] = event.split(':');
            if (pr === 'nt' && this.__touch) {
              return;
            }
            if (pr === 't' && !this.__touch) {
              return;
            }
            return this.$el.on(`${ev}.delegateEvents${this._id}`, el_str, fn_binded);
          });
        });
      }

      __events_undelegate() {
        return this.$el.off('.delegateEvents' + this._id);
      }

      options_update(options, force = false) {
        var k, previous, v;
        previous = {};
        for (k in options) {
          v = options[k];
          if (force || !_.isEqual(this.options[k], v)) {
            previous[k] = _.cloneDeep(this.options[k]);
            this.options[k] = this.options_pre[k] ? this.options_pre[k].bind(this)(v) : v;
          }
        }
        if (Object.keys(previous).length === 0) {
          return;
        }
        this.__options_bind.concat((this.__views || []).reduce((acc, view) => {
          var view_filter;
          view_filter = (view.__subview_options_binded || []).filter((event) => {
            return event.id === this._id;
          });
          return acc.concat(view.__subview_options_binded || []);
        }, [])).filter(function(v) {
          return Object.keys(previous).filter(function(up) {
            return v.events.indexOf(up) >= 0;
          }).length > 0;
        }).forEach(function(v) {
          return v.fn(previous);
        });
        Object.keys(previous).forEach((option) => {
          return this.trigger(`${update_ev}:${option}`);
        });
        return this.trigger(update_ev);
      }

      options_update_bind(option, exec) {
        return this.bind(`${update_ev}:${option}`, () => {
          return exec(this.options[option]);
        });
      }

      options_update_unbind(option, exec = null) {
        return this.unbind(`${update_ev}:${option}`, exec);
      }

      __option_get_from_str(str) {
        var res;
        res = str.trim().replace('&amp;', '&').match(/^(?:\&)\=([\w\.&\]\[]*)$/);
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
        }).apply(this).map((i) => {
          return {
            option: this.__option_get_from_str(attributes[i].value),
            name: attributes[i].name
          };
        }).filter(function({option}) {
          return !!option;
        }).forEach(({name, option}) => {
          return this.option_bind_el_attr(el, name, option)();
        });
        option = this.__option_get_from_str($(el).html());
        if (option) {
          return this.option_bind_el_attr(el, 'html', option)();
        }
      }

      option_bind_el_attr(el, attr, option) {
        var arrayed, exec, opt_get, options, val_get;
        boundMethodCheck(this, View);
        // check is array
        arrayed = option.match(/^([\w]*)\[([\d]*)\]$/);
        if (arrayed) {
          option = arrayed[1];
        }
        opt_get = () => {
          var j, len, op, ref, v;
          op = this.options;
          ref = option.split('.');
          for (j = 0, len = ref.length; j < len; j++) {
            v = ref[j];
            op = op[v];
            if (op === null) {
              break;
            }
          }
          return op;
        };
        val_get = this.options_html[option] ? () => {
          return (arrayed ? this.options_html[option][arrayed[2]] : this.options_html[option]).bind(this)(opt_get());
        } : () => {
          return opt_get();
        };
        options = [option];
        if (option.indexOf('&') >= 0) {
          options = option.split('&');
          val_get = ((options) => {
            return () => {
              return options.filter((option) => {
                return this.options[option];
              }).length === options.length;
            };
          })(options);
        }
        exec = () => {
          var val;
          val = val_get();
          if (attr === 'html') {
            return $(el)[attr](val);
          }
          if ((val == null) || val === false) {
            return $(el).removeAttr(attr);
          }
          return $(el).attr(attr, val);
        };
        options.forEach((option) => {
          this.bind(`${update_ev}:${option}`, exec);
          return this.__events_binded_el.push(`${update_ev}:${option}`);
        });
        return exec;
      }

      render() {
        this.subview_remove();
        if (this.__rendering) {
          return this;
        }
        this.__rendering = true;
        (() => {
          var ev, results;
          results = [];
          while (ev = this.__events_binded_el.shift()) {
            results.push(this.unbind(ev));
          }
          return results;
        })();
        this.__options_bind.forEach((v) => {
          return v.fn(this.options);
        });
        if (!this.template_compiled) {
          if (this.template) {
            this.template_compiled = _.template(this.template);
          }
        }
        if (this.template_compiled) {
          this.$el.html(this.template_compiled({
            self: this
          }));
        }
        this.$el.find('[class]').forEach((el) => {
          return $(el).attr('class', this.__selector_parse($(el).attr('class')));
        });
        (() => {
          var attr, get, option, ref, results;
          get = () => {
            if (!Array.isArray(this.options_bind_el_self)) {
              return this.options_bind_el_self;
            }
            return this.options_bind_el_self.reduce(function(acc, v) {
              return Object.assign(acc, {
                [`data-${v}`]: v
              });
            }, {});
          };
          ref = get();
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
        this.__rendering = false;
        if (this.smooth_appear) {
          this.$el.attr('data-add', '');
          this.$el.height();
          this.$el.removeAttr('data-add');
        }
        return this;
      }

      subview_append(view, events = [], options_bind = {}) {
        if (!this.__subview) {
          this.__subview = [];
        }
        this.__subview.push(view);
        this.subview_events_pass(events, view);
        this.subview_options_bind(options_bind, view);
        return view;
      }

      subview_options_bind(options_bind, view, parent = this) {
        if (Array.isArray(options_bind)) {
          options_bind = options_bind.reduce(function(acc, v) {
            return Object.assign(acc, {
              [v]: v
            });
          }, {});
        }
        parent.__views = (parent.__views || []).concat(view);
        view.__subview_options_binded = Object.keys(options_bind).reduce((acc, key) => {
          var fn, value;
          value = options_bind[key];
          fn = () => {
            return view.options_update({
              [value]: parent.options[key]
            }, true);
          };
          fn();
          return acc.concat({
            events: key.split(','),
            fn,
            id: parent._id
          });
        }, view.__subview_options_binded || []);
        view.on('remove', () => {
          if (parent.__views) {
            return parent.__views = parent.__views.filter(function(v) {
              return v._id !== view._id;
            });
          }
        });
        parent.on('remove', () => {
          if (view.__subview_options_binded) {
            return view.__subview_options_binded = view.__subview_options_binded.filter(function(event) {
              return event.id !== parent._id;
            });
          }
        });
        return this;
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
        this.__background_click_callback_remove();
        this.$el.addClass('hidden');
        this.trigger('hide');
        return this;
      }

      __is_visible() {
        return !this.$el.hasClass('hidden');
      }

      show() {
        this.$el.removeClass('hidden');
        this.trigger('show');
        if (this.background_click_hide) {
          this.__background_click_callback_add(this.hide.bind(this));
        }
        return this;
      }

      show_hide() {
        if (!this.__is_visible()) {
          return this.show();
        }
        return this.hide();
      }

      hide_show() {
        return this.show_hide();
      }

      __background_click_callback_add(callback) {
        this.__background_click_callback_remove();
        return setTimeout(() => {
          // it is timeout beacause bubbled to body click event
          if (this.__removed) {
            return;
          }
          this.__background_click_callback = function() {
            return callback();
          };
          return __body.bind('click', this.__background_click_callback);
        }, 0);
      }

      __background_click_callback_remove() {
        if (this.__background_click_callback) {
          __body.unbind('click', this.__background_click_callback);
          return this.__background_click_callback = null;
        }
      }

      remove() {
        this.__removed = true;
        this.__background_click_callback_remove();
        this.subview_remove();
        super.remove(...arguments);
        this.__events_undelegate();
        delete this.__subview_options_binded;
        return this.$el.remove();
      }

      __selector_parse(s, point = false) {
        return s.replace(/&-/g, `${point ? '.' : ''}${this.className}-`).replace(/--/g, `${point ? '.' : ''}${this.className}-`);
      }

      $(selector) {
        return this.$el.find(this.__selector_parse(selector, true));
      }

    };

    View.prototype.background_click_hide = false;

    View.prototype.smooth_appear = false;

    View.prototype.className = null;

    View.prototype.el = 'div';

    View.prototype.template = '';

    View.prototype.events = {};

    View.prototype.options_html = {};

    //   data-s=' &=attr&attr2 '
    //   data-s=' &=options_html[1] '
    View.prototype.options_bind = {};

    View.prototype.options_bind_el_self = {}; // or []

    View.prototype.options_pre = {};

    return View;

  }).call(this);

}).call(this);
