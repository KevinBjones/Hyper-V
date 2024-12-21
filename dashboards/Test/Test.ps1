New-UDApp -Title "Test" -Content {
$Data = @(
     @{Dessert = 'Frozen yoghurt'; Calories = 159; Fat = 6.0; Carbs = 24; Protein = 4.0}
     @{Dessert = 'Ice cream sandwich'; Calories = 159; Fat = 6.0; Carbs = 24; Protein = 4.0}
     @{Dessert = 'Eclair'; Calories = 159; Fat = 6.0; Carbs = 24; Protein = 4.0}
     @{Dessert = 'Cupcake'; Calories = 159; Fat = 6.0; Carbs = 24; Protein = 4.0}
     @{Dessert = 'Gingerbread'; Calories = 159; Fat = 6.0; Carbs = 24; Protein = 4.0}
 ) 
 $Columns = @(
     New-UDTableColumn -Property Dessert -Title Dessert -Render { 
        New-UDButton -Id "btn$($EventData.Dessert)" -Text "Click for Dessert!" -OnClick { Show-UDToast -Message $EventData.Dessert } 
     }
     New-UDTableColumn -Property Calories -Title Calories 
     New-UDTableColumn -Property Fat -Title Fat 
     New-UDTableColumn -Property Carbs -Title Carbs 
     New-UDTableColumn -Property Protein -Title Protein 
 )
 New-UDTable -Data $Data -Columns $Columns -Id 'table3'
}