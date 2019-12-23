Popup = window.o.ViewPopup


window.o.ViewPopupIframe = class PopupAuthorize extends Popup
  className: Popup::className + '-iframe'
  options_default:
    close: true
    body: _.template """
      <iframe frameborder='0' src='<%= self.options.link %>' style='width:100%;height:100%;'>
    """
