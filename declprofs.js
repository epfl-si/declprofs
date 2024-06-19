function showDiv (id) {
	document.getElementById(id).style.display = 'block' ;
}
function hideDiv (id) {
	document.getElementById(id).style.display = 'none' ;
}

function delItem (year, index) {
	var item = document.getElementById(year+'item_'+index);
	item.parentNode.removeChild(item);
}

function toggleEdit (year) {

console.log ('toggleEdit start, display='+document.getElementById('yearact_mod'+year).style.display);
	if ( document.getElementById('yearact_mod'+year).style.display != 'block' ) {
console.log ('toggleEdit A');
		showDiv('yearact_mod'+year); 
		hideDiv('yearact'+year)
	} else {
console.log ('toggleEdit B');
		hideDiv('yearact_mod'+year); 
		showDiv('yearact'+year)
	}
}

function insertItem(year, index) {
	var node = document.createElement("div");
	var new_index = index.toString() + '1';
	var itemHTML = '<div class="row underlined"  id="'+year+'item_'+new_index+'">' +
				'<div class="col-md-2" style="text-align: right;">' +
				'	<span class="btn btn-xs btn-info"  onclick="insertItem(\''+year+'\', \''+new_index+'\');"><span class="glyphicon glyphicon-plus"></span></span>' +
				'	<span class="btn btn-xs btn-warning" onclick="if (confirm(\'delete this entry\')) delItem(\''+year+'\', \''+new_index+'\');"><span class="glyphicon glyphicon-trash"></span></span>' +
				'</div>' +
				'<div class="col-md-3">' +
				'	<textarea name="'+year+'activity_'+new_index+'"  class="no_borders" id="activity_'+new_index+'"></textarea>' +
				'</div>' +
				'<div class="col-md-3">' +
				'	<textarea name="'+year+'principal_'+new_index+'"  class="no_borders" id="principal_'+new_index+'"></textarea>' +
				'</div>' +
				'<div class="col-md-2">' +
				'	<input type="date" name="'+year+'dateFrom_'+new_index+'"  class="no_borders" id="dateFrom_'+new_index+'" min="'+year+'-01-01" max="'+year+'-12-31"  required>' +
				'</div>' +
				'<div class="col-md-2">' +
				'	<input type="date" name="'+year+'dateTo_'+new_index+'"  class="no_borders" id="dateTo_'+new_index+'" min="'+year+'-01-01" max="'+year+'-12-31" required>' +
				'</div>' +
				'</div>';
	node.innerHTML = itemHTML;
	node.id = year+'item_'+new_index;
	var referencenode = document.getElementById(year+'item_'+index);
	referencenode.parentNode.insertBefore(node, referencenode.nextSibling);

}

function loadHistory (url) {

	var obj = new XMLHttpRequest();
	obj.open("GET", url);
	obj.send();
	obj.onreadystatechange=function() 
	{
	  if(obj.readyState==4) 
		document.getElementById('history_items').innerHTML = obj.responseText; 
//		doscripts (document.getElementById(div_id));
//		doscripts (document);
		document.getElementById('history').style.display = 'block'; 
	}
}

function checkAll (formname, checkstatus) {
  var checkboxes = new Array(); 
			checkboxes = document[formname].getElementsByTagName('input');
  for (var i=0; i<checkboxes.length; i++)  {
    if (checkboxes[i].type == 'checkbox')   {
			checkboxes[i].checked = checkstatus;	
		}
	} 
	return checkboxes;
}
