Popup = window.o.ViewPopup


window.o.ViewPopupAuthorize = class PopupAuthorize extends Popup
  className: Popup::className + '-authorize'
  options_default:
    close: false
    head: _.template """<%= _l('Authorize.head') %>"""
    body: _.template """
      <div class='&-legal'>
        <%= _l('Authorize.legal.head', {
          terms: '<a target="_blank" href="'+ App.config.legal.terms +'">' + _l('Authorize.legal.terms') + '</a>',
          privacy: '<a target="_blank" href="'+ App.config.legal.privacy +'">' + _l('Authorize.legal.privacy') + '</a>'
        }) %>
      </div>
      <div class='&-buttons'>
        <% self.options.platforms.forEach(function (platform) { %>

          <button data-click='authorize' data-click-attr='<%= platform %>'><%= platform %></button>
        <% }) %>
      </div>
      <p>
        <%= _l('Authorize.desc') %>
      </p>
    """
