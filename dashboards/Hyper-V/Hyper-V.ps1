New-UDApp -Content {
   New-UDButton -Text 'Click Me' -OnClick {
       Show-UDToast "Ouch!"
   }
}