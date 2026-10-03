var Values = {};

function CreateItem(name)
{
	var el = document.createElement("div");
	el.className = "item";
	document.getElementById("inventory_panel_player").appendChild(el);
	var nameP = document.createElement("p");
	nameP.appendChild(document.createTextNode(name));
	el.appendChild(nameP);
}

function UpdateValue(val)
{
	if (!Values[val])
		Values[val] = false;
	Values[val] = !Values[val];
}

$(function()
{
	window.addEventListener('message', function(event) {
		if (event.data.type == "ze_ui_toggle") {
			var disp = event.data.toggle ? "block" : "none";
			document.body.style.display = disp;
		} else if (event.data.type == "createItem")
		{
			CreateItem(event.data.name);
		}
		else if (event.data.type == "default")
		{
			$("#Right_Back_Door").attr('src', "door.png");
			$("#Right_Back_Window").attr('src', "window.png");
			
			$("#Left_Back_Window").attr('src', "window.png");
			$("#Left_Back_Door").attr('src', "door.png");
			
			$("#Right_Front_Door").attr('src', "door.png");
			$("#Right_Front_Window").attr('src', "window.png");
			
			$("#Left_Front_Door").attr('src', "door.png");
			$("#Left_Front_Window").attr('src', "window.png");
		}
	});

	document.onkeyup = function (data) {
		$.post('http://ze_car_ui/press', JSON.stringify({
				key: data.key,
				which: data.which
		}));
        if (data.which == 27) { // Escape key = 27 H = 72
           
        }
    };
	
	$("#Right_Back_Door").click(function() {	
        UpdateValue("RBD");
		if (Values["RBD"])
			$("#Right_Back_Door").attr('src', "door2.png");
		else
			$("#Right_Back_Door").attr('src', "door.png");
        $.post('http://ze_car_ui/clicked', JSON.stringify({
            type: "door",
			type2: 3,
            value: Values["RBD"]
        }));
    });
	$("#Right_Back_Window").click(function() {
        
        UpdateValue("RBW");
		if (Values["RBW"])
			$("#Right_Back_Window").attr('src', "window2.png");
		else
			$("#Right_Back_Window").attr('src', "window.png");
		
        $.post('http://ze_car_ui/clicked', JSON.stringify({
            type: "wind",
			type2: 3,
            value: Values["RBW"]
        }));
    });
	
	$("#Left_Back_Door").click(function() {
       UpdateValue("LBD");
	   if (Values["LBD"])
			$("#Left_Back_Door").attr('src', "door2.png");
		else
			$("#Left_Back_Door").attr('src', "door.png");
		
        $.post('http://ze_car_ui/clicked', JSON.stringify({
            type: "door",
			type2: 2,
            value: Values["LBD"]
        }));
    });
	$("#Left_Back_Window").click(function() {
        
        UpdateValue("LBW");
		if (Values["LBW"])
			$("#Left_Back_Window").attr('src', "window2.png");
		else
			$("#Left_Back_Window").attr('src', "window.png");
		
		
        $.post('http://ze_car_ui/clicked', JSON.stringify({
            type: "wind",
			type2: 2,
            value: Values["LBW"]
        }));
    });
	
	$("#Right_Front_Door").click(function() {
       UpdateValue("RFD");
		if (Values["RFD"])
			$("#Right_Front_Door").attr('src', "door2.png");
		else
			$("#Right_Front_Door").attr('src', "door.png");
		
        $.post('http://ze_car_ui/clicked', JSON.stringify({
            type: "door",
			type2: 1,
            value: Values["RFD"]
        }));
    });
	$("#Right_Front_Window").click(function() {
        
        UpdateValue("RFW");
		if (Values["RFW"])
			$("#Right_Front_Window").attr('src', "window2.png");
		else
			$("#Right_Front_Window").attr('src', "window.png");
        $.post('http://ze_car_ui/clicked', JSON.stringify({
            type: "wind",
			type2: 1,
            value: Values["RFW"]
        }));
    });
	
	$("#Left_Front_Door").click(function() {
        UpdateValue("LFD");
		if (Values["LFD"])
			$("#Left_Front_Door").attr('src', "door2.png");
		else
			$("#Left_Front_Door").attr('src', "door.png");
        $.post('http://ze_car_ui/clicked', JSON.stringify({
            type: "door",
			type2: 0,
            value: Values["LFD"]
        }));
    });
	$("#Left_Front_Window").click(function() {
        
         UpdateValue("LFW");
		 if (Values["LFW"])
			$("#Left_Front_Window").attr('src', "window2.png");
		else
			$("#Left_Front_Window").attr('src', "window.png");
		
		
        $.post('http://ze_car_ui/clicked', JSON.stringify({
            type: "wind",
			type2: 0,
            value: Values["LFW"]
        }));
    });
	
	$("#Trunk_Door").click(function() {
        
         UpdateValue("TD");
		if (Values["TD"])
			$("#Trunk_Door").attr('class', "ut_on");
		else
			$("#Trunk_Door").attr('class', "ut_button");
        $.post('http://ze_car_ui/clicked', JSON.stringify({
            type: "door",
			type2: 5,
            value: Values["TD"]
        }));
    });
	$("#Hood_Door").click(function() {
        
        UpdateValue("HD");
		if (Values["HD"])
			$("#Hood_Door").attr('class', "ut_on");
		else
			$("#Hood_Door").attr('class', "ut_button");
		
		
        $.post('http://ze_car_ui/clicked', JSON.stringify({
            type: "door",
			type2: 4,
            value: Values["HD"]
        }));
    });
	$("#Engine").click(function() {
        
        UpdateValue("Engine");
		if (Values["Engine"])
			$("#Engine").attr('class', "ut_on");
		else
			$("#Engine").attr('class', "ut_button");
		$("#Trunk_Door").attr('class', "ut_button");
		$("#Hood_Door").attr('class', "ut_button");
        $.post('http://ze_car_ui/clicked', JSON.stringify({
            type: "Engine",
            value: Values["Engine"]
        }));
    });
	$("#Neon").click(function() {
        
        UpdateValue("Neon");
		if (!Values["Neon"])
			$("#Neon").attr('class', "ut_on");
		else
			$("#Neon").attr('class', "ut_button");
        $.post('http://ze_car_ui/clicked', JSON.stringify({
            type: "Neon",
            value: Values["Neon"]
        }));
    });
});

