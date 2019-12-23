Popup = window.o.ViewPopup


class PopupEmail extends Popup
  className: Popup::className + '-authorize-email'

  render: ->
    super ...arguments
    @$email = @$('input[name=email]')
    @$email.focus()
    @


class PopupAuthorizeEmailForget extends PopupEmail
  options_default:
    close: true
    body: _.template """
      <form>
        <input required name="email" placeholder="<%= _l('Authorize.email.email') %>" maxlength='64' type="email" value='<%= self.options.email || '' %>' />
        <div class='&-buttons'>
          <button><%= _l('Authorize.email.forget') %></button>
        </div>
      </form>
    """
  events: Object.assign {}, Popup::events, {
    'submit form': (e)->
      e.preventDefault()
      @trigger 'forget', {
        email: @$email.val()
      }
      @remove()
  }


class PopupAuthorizeEmail extends PopupEmail
  options_default:
    close: true
    body: _.template """
      <form>
        <input required name="email" placeholder="<%= _l('Authorize.email.email') %>" maxlength='64' type="email" /><br />
        <input required name="password" placeholder="<%= _l('Authorize.email.pass') %>" type="password" /><br />
        <div class='&-buttons'>
          <button><%= _l('Authorize.email.login') %></button>
          <span data-forget><%= _l('Authorize.email.forget') %></span>
        </div>
      </form>
    """

  events: Object.assign {}, Popup::events, {
    'submit form': (e)->
      e.preventDefault()
      @trigger 'authorize', {
        email: [ @$email.val(), @$('input[name=password]').val() ]
      }
    'click [data-forget]': ->
      @subview_append new PopupAuthorizeEmailForget({ parent: @options.parent, email: @$('input[name=email]').val() }), ['forget']
      .render()
  }


window.o.PlatformEmail =
  _auth_email_events: ->
    if @_auth_email_events_active
      return
    @_auth_email_events_active = true
    fn = (event, data)=>
      if event is 'authenticate:email_forget'
        @router.subview_append new Popup({parent: @router.$el, body: data.body})
        .render()
      if event is 'authenticate:success'
        @router.unbind 'request', fn
    @router.bind 'request', fn

  auth_email: ->
    @_auth_email_events()
    authorize = @router.subview_append new PopupAuthorizeEmail({parent: @router.$el})
    authorize.bind 'authorize', (params)=> @auth_send params
    authorize.bind 'forget', (params)=>
      @router.send 'authenticate:email_forget', Object.assign( {language: App.lang}, params )
    authorize.bind 'remove', => @auth_popup()
    authorize.render()
