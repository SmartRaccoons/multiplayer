Popup = window.o.ViewPopup


window.o.ViewPopupAuthorize = class PopupAuthorize extends Popup
  className: Popup::className + '-authorize'
  options_default:
    close: false
    head: _.template """<%= _l('Authorize') %>"""
    body: _.template """
      <p>
        <% self.options.platforms.forEach(function (platform) { %>

          <button data-click='authorize' data-click-attr='<%= platform %>' class='<%= self.className %>-<%= platform %>'><%= platform %></button>
        <% }) %>
      </p>
      <p>
        <%= _l('Authorize desc') %>
      </p>
    """
