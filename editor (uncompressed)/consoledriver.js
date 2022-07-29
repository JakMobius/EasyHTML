!function(){
	function n(n,o){
		n.toString=function(){
			return"function "+o+"() {\n  [native code]\n}"
		},
		n.toString.toString=function(){
			return"function toString() {\n  [native code]\n}"
		},
		n.toString.toString.toString=n.toString.toString
	}

	var init = false

	function EasyHTMLConstructor() {
		if(init) throw new Error("EasyHTML instance cannot be created by user")
		init = true
	}

	n(EasyHTMLConstructor, "EasyHTMLConstructor")

	window.EasyHTML = new EasyHTMLConstructor()
	window.addEventListener("error",function(n){
		var e = n.error

		if(e == null) {
			s([n.message],2)
		} else {
			s([n.error],2)
		}
	})
	var context = ""
	function clearColorContext() {
		context = ""
	}
	function addColorToContext(color, length, cursive) {
		context += color + ";" + (cursive ? -length : length) + ";"
	}

	function q(n){
		return Array.prototype.slice.call(n)
	}

	var no_color = -1
	var string_color = 0
	var keyword_color = 1
	var number_color = 2
	var key_color = 3
	var error_color = 4

	function stringdesc(a) {
		a = a.replace(/\\/mg, "\\\\")
		a = a.replace(/\"/mg, "\\\"")
		addColorToContext(string_color, a.length + 2)
		return '"' + a + '"'
	}
	function arraydesc(a) {
		var n = "[";
		addColorToContext(no_color, 1)
		var long = a.length > 10
		if(long) a = a.slice(0,10);
		var i = 0;
		a.forEach(function(e) {
			if(i++ != 0) {
				n += ", "
				addColorToContext(no_color, 2)
			}
			if(Array.isArray(e)) {
				if(e.length == 0) {
					n += "[]"
					addColorToContext(no_color, 2)
				} else {
					n += "Array"
					addColorToContext(no_color, 5)
				}
				
			} else {
				n += desc(e, true)
			}
		})

		if(long) {
			n += "..."
			addColorToContext(no_color, 4)
		} else {
			addColorToContext(no_color, 1)
		}
		n += "]"
		
		return n
	}
	function objectdesc(a) {

		var max = 100
		var cname = String(a)
		var n = String(cname)
		addColorToContext(no_color, cname.length)
		var m = Object.getOwnPropertyNames(a)
		var l = m.length
		for (var i = 0, l1 = Math.min(l, max); i < l1; i++) {
			var mi = m[i]
			var ki

			n += "\n" + mi + ": "
			addColorToContext(key_color, mi.length + 3)

			try {
				ki = a[mi]

				n += desc(ki, true)
			} catch(error) {
				ki = String(error)

				n += ki
				addColorToContext(error_color, ki.length)
			}
		}
		if(l > max) {
			var more = "\n" + (l - max) + " more..."
			n += more
			addColorToContext(no_color, more.length, true)
		}

		return n
	}

	function desc(a, short) {
		if(a === null) {
			addColorToContext(keyword_color, 4)
			return "null"
		}
		if(a === undefined) {
			addColorToContext(keyword_color, 9)
			return "undefined"
		}

		var string = a.toString()
		var type = typeof a

		if(isNaN(a) && type == "number") {
			addColorToContext(keyword_color, 3)
			return "NaN"
		}

		if(Array.isArray(a)) {
			return arraydesc(a)
		}
		if(type == "string"){
			return stringdesc(a)
		}
		if(type == "function") {
			var n = "ƒ "
			var tostring = a.toString()
			var description
			if(short) {
				description = a.name + tostring.substring(tostring.indexOf("("), tostring.indexOf(")") + 1) + "{ ... }"
			} else {
				description = a.name + tostring.substring(tostring.indexOf("("))
			}
			n += description
			addColorToContext(keyword_color, 2, true)
			addColorToContext(no_color, description.length, true)
			return n
		}
		if(type == "number" || type == "boolean") {
			addColorToContext(number_color, string.length)
			return string
		}

		addColorToContext(no_color, string.length)
		return string
	}

	function s(n,o){
		var str = typeof s == "string"
		var ar = Array.isArray(n);
		var e=ar?n.length:0;

		if(!str) {
			if(e <= 1) {
				if(1==e) {
					n = n[0]
				}
				if(n === null) {
					n = "null"
					addColorToContext(keyword_color, 4)
				} else if(Array.isArray(n) || typeof n != "object") {
					n = desc(n)
				} else {
					n = objectdesc(n)
				}
			} else {
				n = arraydesc(q(n))
			}
		}

		webkit.messageHandlers.m.postMessage([n,o,context])

		clearColorContext()
	}
	console.log=function(){
		s(q(arguments),0)
	}
	console.warn=function(){
		s(q(arguments),1)
	}
	console.error=function(){
		s(q(arguments),2)
	}
	console.info=function(){
		s(q(arguments),3)
	}
	console.debug=function(){
		s(q(arguments),4)
	}
	console.clear=function(){
		webkit.messageHandlers.q.postMessage(0)
	}
	n(s, "s_private")
	n(console.log,"log")
	n(console.error,"error")
	n(console.clear,"clear")
	n(console.info,"info")
	n(console.debug,"debug")
	n(console.warn,"warn")
	Object.defineProperties(window.EasyHTML, {
    	_s: {enumerable: false, value: s},
	});
}();
