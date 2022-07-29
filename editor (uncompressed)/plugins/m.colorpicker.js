! function(e) {
    function r(e, r) {
        "setValue" == r.origin || r.text || "\n" == r.text ? (e.state.colorpicker.init_color_update(), e.state.colorpicker.style_color_update()) : e.state.colorpicker.style_color_update(e.getCursor().line)
    }

    function t(e, r) {
        e.state.colorpicker.isUpdate || (e.state.colorpicker.isUpdate = !0, e.state.colorpicker.init_color_update(), e.state.colorpicker.style_color_update())
    }

    function a(e, t) {
        r(e, {
            origin: "setValue"
        })
    }

    function i(e, t) {
        r(e, {
            origin: "setValue"
        })
    }

    function n(e, r) {
        this.cm = e, this.markers = {}, this.cm.colorpicker ? this.colorpicker = this.cm.colorpicker() : this.opt.colorpicker && (this.colorpicker = this.opt.colorpicker), this.init_event()
    }
    e.defineExtension("colorpicker", function() {
        var e = function(e, t) {
                function a(e) {
                    function t(r) {
                        for (var t = r + 1; a > r; r++)
                            if (!isNaN(e[r][1])) return t
                    }
                    for (var a = e.length, i = 0; a > i; i++) {
                        var n = e[i],
                            o = n;
                        if (o.startsWith("rgb") || o.startsWith("hsv")) o = o.substr(0, Math.min(o.indexOf(")") + 1, o.length));
                        else {
                            var s = o.indexOf(" "); - 1 == s && (s = o.length), o = o.substr(0, s)
                        }(n = r.trim(n.substr(o.length))).endsWith("%") || "0" == n || (n = "");
                        var l = r.parse(o, !0);
                        if (null == l) return null;
                        e[i] = l.concat(parseInt(n))
                    }
                    isNaN(e[0][4]) && (e[0][4] = 0), isNaN(e[a - 1][4]) && (e[a - 1][4] = 100), i = 1;
                    for (var c = e[0][4]; a > i; i++) {
                        for (var d = !0, u = 0, h = c; isNaN(e[i][4]);) {
                            if (d) {
                                var g = t(i),
                                    p = g - i + 1;
                                u = (e[g][4] - h) / p, d = !1
                            }
                            if (h += u, e[i][4] = h, ++i == a) break
                        }
                        a > i && (c = e[i][4])
                    }
                    return e
                }
                if ("string" == typeof e) {
                    e = e.replace(t, "");
                    var i = document.createElement("div");
                    if (i.style.background = e, !i.style.background) return null;
                    delete i;
                    for (var n = -1 != e.indexOf("radial"), s = 0, l = (e = function(e, r) {
                            for (var t = [""], a = 0, i = 0, n = e.length, o = 0; n > i; i++) {
                                var s = e[i];
                                0 != a || "," != s ? (t[o] += s, "(" == s ? a++ : ")" == s && a--) : (t.push(""), o++)
                            }
                            return t
                        }(e.substr(0, e.length - 1).substr(16))).length; l > s; s++) e[s] = r.trim(e[s]);
                    if (n) {
                        var c = e[0].startsWith("rgb") || e[0].startsWith("hsv") || e[0].startsWith("#");
                        if (!c) {
                            var d = e[0].indexOf(" "); - 1 == d && (d = e[0].length), o[e[0].substr(0, d)] && (c = !0)
                        }
                        var u = a(c ? e : e.slice(1));
                        return [1, t, c ? "" : e[0]].concat(u)
                    }
                    var h = 0,
                        g = e.slice(1);
                    if (e[0].startsWith("to")) switch (e[0].substr(3)) {
                        case "top":
                            h = 0;
                            break;
                        case "left":
                            h = 270;
                            break;
                        case "right":
                            h = 90;
                            break;
                        case "bottom":
                            h = 0;
                            break;
                        case "top left":
                            h = 315;
                            break;
                        case "top right":
                            h = 45;
                            break;
                        case "bottom left":
                            h = 225;
                            break;
                        case "bottom right":
                            h = 135
                    } else e[0].endsWith("deg") ? h = parseInt(e[0]) : e[0].endsWith("grad") ? h = .9 * parseInt(e[0]) : e[0].endsWith("rad") ? h = 57.2958 * parseInt(e[0]) : g = e;
                    return [0, t, h].concat(a(g))
                }
            },
            r = {
                trim: function(e) {
                    return e.replace(/^\s+|\s+$/g, "")
                },
                parse: function(e, t) {
                    if ("string" == typeof e) {
                        var a = e;
                        if (a.indexOf("rgb(") > -1) {
                            for (var i = 0, n = (l = a.replace("rgb(", "").replace(")", "").split(",")).length; n > i; i++) l[i] = parseInt(l[i], 10);
                            return l[3] = 1, t || (l[4] = e), l
                        }
                        if (a.indexOf("rgba(") > -1) {
                            for (i = 0, n = (l = a.replace("rgba(", "").replace(")", "").split(",")).length; n > i; i++) l[i] = n - 1 == i ? parseFloat(l[i]) : parseInt(l[i], 10);
                            return t || (l[4] = e), l
                        }
                        if (a.indexOf("hsl(") > -1) {
                            for (i = 0, n = (l = a.replace("hsl(", "").replace(")", "").split(",")).length; n > i; i++) l[i] = parseInt(r.trim(l[i]), 10);
                            var s = r.HSLtoRGB(obj.h, obj.s, obj.l);
                            return t ? [s.r, s.g, s.b, 1] : [s.r, s.g, s.b, 1, e]
                        }
                        if (a.indexOf("hsla(") > -1) {
                            for (i = 0, n = (l = a.replace("hsla(", "").replace(")", "").split(",")).length; n > i; i++) l[i] = n - 1 == i ? parseFloat(l[i]) : parseInt(l[i], 10);
                            return s = r.HSLtoRGB(obj.h, obj.s, obj.l), obj.r = s.r, obj.g = s.g, obj.b = s.b, t ? [s.r, s.g, s.b, l[3]] : [s.r, s.g, s.b, l[3], e]
                        };
                        if (a.startsWith("#")) {
                            var l = [];
                            if (3 == (a = a.replace("#", "")).length)
                                for (i = 0, n = a.length; n > i; i++) {
                                    var c = a.substr(i, 1);
                                    l.push(parseInt(c + c, 16))
                                } else
                                    for (i = 0, n = a.length; n > i; i += 2) l.push(parseInt(a.substr(i, 2), 16));
                            return l[3] = 1, t || (l[4] = e), l
                        }
                        var d = o[a];
                        return d ? (d = d.slice(0), t || d.push(e), d) : null
                    }
                    return null
                },
                HSVtoRGB: function(e, r, t) {
                    360 == e && (e = 0);
                    var a = r * t,
                        i = a * (1 - Math.abs(e / 60 % 2 - 1)),
                        n = t - a,
                        o = [];
                    return e >= 0 && 60 > e ? o = [a, i, 0] : e >= 60 && 120 > e ? o = [i, a, 0] : e >= 120 && 180 > e ? o = [0, a, i] : e >= 180 && 240 > e ? o = [0, i, a] : e >= 240 && 300 > e ? o = [i, 0, a] : e >= 300 && 360 > e && (o = [a, 0, i]), {
                        r: Math.ceil(255 * (o[0] + n)),
                        g: Math.ceil(255 * (o[1] + n)),
                        b: Math.ceil(255 * (o[2] + n))
                    }
                },
                RGBtoHSV: function(e, r, t) {
                    var a = e / 255,
                        i = r / 255,
                        n = t / 255,
                        o = Math.max(a, i, n),
                        s = o - Math.min(a, i, n),
                        l = 0;
                    return 0 == s ? l = 0 : o == a ? l = (i - n) / s % 6 * 60 : o == i ? l = 60 * ((n - a) / s + 2) : o == n && (l = 60 * ((a - i) / s + 4)), 0 > l && (l = 360 + l), {
                        h: l,
                        s: 0 == o ? 0 : s / o,
                        v: o
                    }
                },
                RGBtoHSL: function(e, r, t) {
                    e /= 255, r /= 255, t /= 255;
                    var a, i, n = Math.max(e, r, t),
                        o = Math.min(e, r, t),
                        s = (n + o) / 2;
                    if (n == o) a = i = 0;
                    else {
                        var l = n - o;
                        switch (i = s > .5 ? l / (2 - n - o) : l / (n + o), n) {
                            case e:
                                a = (r - t) / l + (t > r ? 6 : 0);
                                break;
                            case r:
                                a = (t - e) / l + 2;
                                break;
                            case t:
                                a = (e - r) / l + 4
                        }
                        a /= 6
                    }
                    return {
                        h: Math.round(360 * a),
                        s: Math.round(100 * i),
                        l: Math.round(100 * s)
                    }
                },
                HUEtoRGB: function(e, r, t) {
                    return 0 > t && (t += 1), t > 1 && (t -= 1), .166666666 > t ? e + 6 * (r - e) * t : .555555555 > t ? r : .666666666 > t ? e + (r - e) * (2 / 3 - t) * 6 : e
                },
                HSLtoRGB: function(e, r, t) {
                    var a, i, n;
                    if (e /= 360, t /= 100, 0 == (r /= 100)) a = i = n = t;
                    else {
                        var o = .5 > t ? t * (1 + r) : t + r - t * r,
                            s = 2 * t - o;
                        a = this.HUEtoRGB(s, o, e + 1 / 3), i = this.HUEtoRGB(s, o, e), n = this.HUEtoRGB(s, o, e - 1 / 3)
                    }
                    return {
                        r: 255 * a,
                        g: 255 * i,
                        b: 255 * n
                    }
                }
            };
        return {
            show: function(t, a, i, n, o, s, l, c) {
                window.colorpickerCallback = a;
                var d = l ? e(t, c) : r.parse(t);
                null != d && webkit.messageHandlers[l ? "g" : "c"].postMessage([d, i, n, o, s])
            }
        }
    });
    var o = {
        aliceblue: [240, 248, 255, 1],
        antiquewhite: [250, 235, 215, 1],
        aqua: [0, 255, 255, 1],
        aquamarine: [127, 255, 212, 1],
        azure: [240, 255, 255, 1],
        beige: [245, 245, 220, 1],
        bisque: [255, 228, 196, 1],
        black: [0, 0, 0, 1],
        blanchedalmond: [255, 235, 205, 1],
        blue: [0, 0, 255, 1],
        blueviolet: [138, 43, 226, 1],
        brown: [165, 42, 42, 1],
        burlywood: [222, 184, 135, 1],
        cadetblue: [95, 158, 160, 1],
        chartreuse: [127, 255, 0, 1],
        chocolate: [210, 105, 30, 1],
        coral: [255, 127, 80, 1],
        cornflowerblue: [100, 149, 237, 1],
        cornsilk: [255, 248, 220, 1],
        crimson: [237, 20, 61, 1],
        cyan: [0, 255, 255, 1],
        darkblue: [0, 0, 139, 1],
        darkcyan: [0, 139, 139, 1],
        darkgoldenrod: [184, 134, 11, 1],
        darkgray: [169, 169, 169, 1],
        darkgrey: [169, 169, 169, 1],
        darkgreen: [0, 100, 0, 1],
        darkkhaki: [189, 183, 107, 1],
        darkmagenta: [139, 0, 139, 1],
        darkolivegreen: [85, 107, 47, 1],
        darkorange: [255, 140, 0, 1],
        darkorchid: [153, 50, 204, 1],
        darkred: [139, 0, 0, 1],
        darksalmon: [233, 150, 122, 1],
        darkseagreen: [143, 188, 143, 1],
        darkslateblue: [72, 61, 139, 1],
        darkslategray: [47, 79, 79, 1],
        darkslategrey: [47, 79, 79, 1],
        darkturquoise: [0, 206, 209, 1],
        darkviolet: [148, 0, 211, 1],
        deeppink: [255, 20, 147, 1],
        deepskyblue: [0, 191, 255, 1],
        dimgray: [105, 105, 105, 1],
        dimgrey: [105, 105, 105, 1],
        dodgerblue: [30, 144, 255, 1],
        firebrick: [178, 34, 34, 1],
        floralwhite: [255, 250, 240, 1],
        forestgreen: [34, 139, 34, 1],
        fuchsia: [255, 0, 255, 1],
        gainsboro: [220, 220, 220, 1],
        ghostwhite: [248, 248, 255, 1],
        gold: [255, 215, 0, 1],
        goldenrod: [218, 165, 32, 1],
        gray: [128, 128, 128, 1],
        grey: [128, 128, 128, 1],
        green: [0, 128, 0, 1],
        greenyellow: [173, 255, 47, 1],
        honeydew: [240, 255, 240, 1],
        hotpink: [255, 105, 180, 1],
        indianred: [205, 92, 92, 1],
        indigo: [75, 0, 130, 1],
        ivory: [255, 255, 240, 1],
        khaki: [240, 230, 140, 1],
        lavender: [230, 230, 250, 1],
        lavenderblush: [255, 240, 245, 1],
        lawngreen: [124, 252, 0, 1],
        lemonchiffon: [255, 250, 205, 1],
        lightblue: [173, 216, 230, 1],
        lightcoral: [240, 128, 128, 1],
        lightcyan: [224, 255, 255, 1],
        lightgoldenrodyellow: [250, 250, 210, 1],
        lightgreen: [144, 238, 144, 1],
        lightgray: [211, 211, 211, 1],
        lightgrey: [211, 211, 211, 1],
        lightpink: [255, 182, 193, 1],
        lightsalmon: [255, 160, 122, 1],
        lightseagreen: [32, 178, 170, 1],
        lightskyblue: [135, 206, 250, 1],
        lightslategray: [119, 136, 153, 1],
        lightslategrey: [119, 136, 153, 1],
        lightsteelblue: [176, 196, 222, 1],
        lightyellow: [255, 255, 224, 1],
        lime: [0, 255, 0, 1],
        limegreen: [50, 205, 50, 1],
        linen: [250, 240, 230, 1],
        magenta: [255, 0, 255, 1],
        maroon: [128, 0, 0, 1],
        mediumaquamarine: [102, 205, 170, 1],
        mediumblue: [0, 0, 205, 1],
        mediumorchid: [186, 85, 211, 1],
        mediumpurple: [147, 112, 219, 1],
        mediumseagreen: [60, 179, 113, 1],
        mediumslateblue: [123, 104, 238, 1],
        mediumspringgreen: [0, 250, 154, 1],
        mediumturquoise: [72, 209, 204, 1],
        mediumvioletred: [199, 21, 133, 1],
        midnightblue: [25, 25, 112, 1],
        mintcream: [245, 255, 250, 1],
        mistyrose: [255, 228, 225, 1],
        moccasin: [255, 228, 181, 1],
        navajowhite: [255, 222, 173, 1],
        navy: [0, 0, 128, 1],
        oldlace: [253, 245, 230, 1],
        olive: [128, 128, 0, 1],
        olivedrab: [107, 142, 35, 1],
        orange: [255, 165, 0, 1],
        orangered: [255, 69, 0, 1],
        orchid: [218, 112, 214, 1],
        palegoldenrod: [238, 232, 170, 1],
        palegreen: [152, 251, 152, 1],
        paleturquoise: [175, 238, 238, 1],
        palevioletred: [219, 112, 147, 1],
        papayawhip: [255, 239, 213, 1],
        peachpuff: [255, 218, 185, 1],
        peru: [205, 133, 63, 1],
        pink: [255, 192, 203, 1],
        plum: [221, 160, 221, 1],
        powderblue: [176, 224, 230, 1],
        purple: [128, 0, 128, 1],
        rebeccapurple: [102, 51, 153, 1],
        red: [255, 0, 0, 1],
        rosybrown: [188, 143, 143, 1],
        royalblue: [65, 105, 225, 1],
        saddlebrown: [139, 69, 19, 1],
        salmon: [250, 128, 114, 1],
        sandybrown: [244, 164, 96, 1],
        seagreen: [46, 139, 87, 1],
        seashell: [255, 245, 238, 1],
        sienna: [160, 82, 45, 1],
        silver: [192, 192, 192, 1],
        skyblue: [135, 206, 235, 1],
        slateblue: [106, 90, 205, 1],
        slategray: [112, 128, 144, 1],
        slategrey: [112, 128, 144, 1],
        snow: [255, 250, 250, 1],
        springgreen: [0, 255, 127, 1],
        steelblue: [70, 130, 180, 1],
        tan: [210, 180, 140, 1],
        teal: [0, 128, 128, 1],
        thistle: [216, 191, 216, 1],
        tomato: [255, 99, 71, 1],
        turquoise: [64, 224, 208, 1],
        violet: [238, 130, 238, 1],
        wheat: [245, 222, 179, 1],
        white: [255, 255, 255, 1],
        whitesmoke: [245, 245, 245, 1],
        yellow: [255, 255, 0, 1],
        yellowgreen: [154, 205, 50, 1],
        transparent: [0, 0, 0, 0]
    };
    e.defineOption("colorpicker", !1, function(e, r, t) {
        e.state.colorpicker = new n(e, r)
    }), n.prototype.init_event = function() {
        function e(e) {
            var r = e.srcElement || e.target;
            (r = r.closest(".codemirror-colorview")) && (e.preventDefault(), e.stopPropagation(), s.open_color_picker(r))
        }
        this.cm.on("change", r), this.cm.on("update", t);
        this.cm.on("viewportChange", function(cm, line, elt) {
            cm.state.colorpicker.style_color_update()
        })
        var n, o, s = this;
        document.body.addEventListener("mousedown", e), document.body.addEventListener("touchstart", e), this.onPasteCallback = (n = this.cm, o = i, function(e) {
            o.call(this, n, e)
        }), this.cm.getWrapperElement().addEventListener("paste", this.onPasteCallback)
    }, n.prototype.open_color_picker = function(e) {
        var r = e.lineNo,
            t = e.ch,
            a = e.color;
        if (this.colorpicker) {
            var i = this,
                n = a,
                o = e.getBoundingClientRect();
            this.colorpicker.show(a, function(e) {
                i.cm.replaceRange(e, {
                    line: r,
                    ch: t
                }, {
                    line: r,
                    ch: t + n.length
                }, "*colorpicker"), n = e
            }, parseInt(o.x || o.left), parseInt(o.y || o.top), parseInt(o.width), parseInt(o.height), e.__isGradient, e.__prefix)
        }
    }, n.prototype.init_color_update = function() {
        this.markers && this.markers.forEach && this.markers.forEach(function(e) {
            e.forEach(function(e) {
                e.remove()
            })
        }), this.markers = []
    }, n.prototype.style_color_update = function(e) {
        if (e) {
            this.markers[e].forEach(function(e){e.remove()})
            delete this.markers[e]
            this.match(e);
        }
        else {
            var start = this.cm.getViewport(), b = start.from, e = start.to;
            for (; b < e; b++) this.match(b)
        }
    }, n.prototype.color_regexp = /(?:-webkit-|-o-|-moz-)?(linear|radial)-gradient\([^)]*\)|(#(?:[\da-f]{3}){1,2}|rgb\((?:\s*\d{1,3},\s*){2}\d{1,3}\s*\)|rgba\((?:\s*\d{1,3},\s*){3}\d*\.?\d+\s*\)|hsl\(\s*\d{1,3}(?:,\s*\d{1,3}%){2}\s*\)|hsla\(\s*\d{1,3}(?:,\s*\d{1,3}%){2},\s*\d*\.?\d+\s*\)|([\w_\-]+))/gi,

     n.prototype.match_result = function(r) {
        for (var e = (r = r.text).length, a = [], t = ["linear-gradient", "radial-gradient", "rgba", "rgb", "hsl"], i = t.length, l = {}, f = 0, n = r[0];
            " " == n || "\t" == n;) n = r[++f];
        for (; f < e; f++) {
            n = r[f];
            for (var s = r.substring(f, f + 15), g = "", h = 0; h < i; h++) {
                var d = t[h];
                if (s.startsWith(d)) {
                    g = d;
                    break
                }
            }
            if (s = null, g) {
                for (f += g.length;
                    " " == r[f];) f++;
                if ("(" == r[f]) {
                    var v = g + "(",
                        b = 1;
                    for (f++; b && void 0 !== (n = r[f++]);) {
                        if (!((u = n.charCodeAt(0)) >= 97 && u <= 122 || u >= 65 && u <= 90 || 46 == u || 44 == u || 32 == u || 35 == u || 37 == u || 40 == u || 41 == u || u >= 48 && u <= 57)) break;
                        v += n, ")" == n ? b-- : "(" == n && b++
                    }
                    b || a.push(v)
                }
            } else {
                for (var c = "", u = n ? n.charCodeAt(0) : void 0; u && u >= 97 && u <= 122 || u >= 65 && u <= 90 || 35 == u || u >= 48 && u <= 57;) c += n, u = (n = r[++f]) ? n.charCodeAt(0) : void 0;
                if (n && n != " " && n != ";" && n != "\"" && n != "\'" && n != " ") c = "";
                if ("#" == c[0]) {
                    var A = c.substring(1),
                        C = A.length,
                        k = 0;
                    u = 0;
                    if (3 != C && 6 != C) c = "";
                    else
                        for (; k < C; k++)
                            if (((u = A[k].charCodeAt(0)) < 48 || u > 57) && (u < 97 || u > 102) && (u < 65 || u > 70)) {
                                c = "";
                                break
                            }
                } else((c.indexOf("#") != -1) || (l[c])) && (c = "");
                "" != c && (a.push(c), c = "")
            }
        }
        return a
    }, n.prototype.match = function(e) {
        var r = this.cm.getLineHandle(e);
        var t = this.match_result(r);
        if (t)
            for (var a = {next: 0}, i = 0, n = t.length; n > i; i++) {
                var s = t[i],
                    l = 6 == s.replace(/^(-webkit-|-o-|-moz-)?/gi, "").indexOf("-gradient");
                s.indexOf("#") > -1 || s.indexOf("rgb") > -1 || s.indexOf("hsl") > -1 || l ? this.render(a, e, r, s, l) : o[s] && this.render(a, e, r, s)
            }
    }, n.prototype.make_element = function() {
        var e = document.createElement("div");
        return e.className = "codemirror-colorview", e.back_element = this.make_background_element(), e.appendChild(e.back_element), e
    }, n.prototype.make_background_element = function() {
        var e = document.createElement("div");
        return e.className = "codemirror-colorview-background", e
    }, n.prototype.set_state = function(e, r, t) {
        var a = this.markers[e][r];
        return a.lineNo = e, a.ch = r, a.color = t, a
    }, n.prototype.create_marker = function(e, r) {
        var t = this.markers[e];
        if (t || (this.markers[e] = [], t = this.markers[e]), !t[r]) {
            var a = this.make_element();
            return t[r] = a, a
        }
        return null
    }, n.prototype.has_marker = function(e, r) {
        var t = this.markers[e];
        return !(!t || !t[r])
    }, n.prototype.update_element = function(e, r) {
        if(!e) return
        var t = e.back_element.style;
        r = r.replace(e.__prefix, ""), t.backgroundColor = r, t.backgroundColor || (t.background = r, t.background || (t.backgroundImage = "url('data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAAYNWlDQ1BJQ0MgUHJvZmlsZQAAWIWVeQVUVV3X7tp7nwQO3d0p3SLd3Skqh27wUIKCCIiUIhKigCggggE2IQKCiCJSIigWSisqBiAl/wbU9/vf7457x11jrL2eMddccz1z9TwHAC4lcnh4MEwPQEhoJMXOWI/fxdWNH/8OUAECoAVyQIPsFRGua2NjAdD0p/zfaWEIQBvlU+kNW/9d/39NDN4+EV4AQDYo9vSO8ApB8U0AMCpe4ZRIALCzqFwoJjIcxTiUJWCmoARRLLyB/baw2gb23MIWmzoOdvoo9gCAQEMmU/wAoN3gxR/t5Yfaoc1C6xhDvQNCUdWzKNby8id7A8A5iupsCwkJQzEXDYrFPf/Djt//sun51yaZ7PcXb/mymQgGARHhweTY/8/h+H+nkOCoP30IoZnGn2Jit+HzxrgFhZlvYJQ79DDU08oaxYwoHgzw3tTfwJP+USaOv/V/ekXoo2MGWAGAabzJBuYo5kaxYFSQo+5vrEWmbLZF9WG3OH8H5y37cCglzO63fTguNNjK4redLH8f0z+4zCfC0P6Pjm+AkSmK0TmE6wMiTR1+23wYHeBkhWJaFL+KCLI3/932Q5y/vtXfvqLsNjijc46AkIg/viDCvhQjuy19RMU/wNTqt9wi0t/BZKststuLvMmBHcWBPhEuFn/4ePsYGG7xQZJ8Qh1/80ROhEfq2f3WrwgPtvmtjzT5BBtvyAVR3BMRbf+n7Vwkuti2fMGAQLKZzVa/GObwSBuHLW4YfmAB9IEB4AdRaPYEYSAQBPTM1s2CPzVGgAwowA/4AOnfkj8tnDdrQtGvPYgDn1DkAyL+ttPbrPUB0ah87a906ysNfDdrozdbBIFJFIdgODFaGA2MBfrVQbMCRg2j/qcdP92fXnGGOAOcCc4IJ7EnIInyL7v8wAv1IBjNFGCOlj6oVxscQv9w/8cOdhLbj32PfYYdxb4ATmAc1Qv4Lw//sRbwV2YJRlGrRr+98/xP7zCiKGtljB5GE+WPcsewYjiBNEYJ9UQXo436poxK/xm1/xP3qD+siXJEmMhG1CGK/1uPVpJW+W+bDd/+k+cWL8+/nuj/rfl3b/r/4Zs3Wpr/WxNJQ24gncg95BHShNQBfqQFqUe6kbsb+O/aGN9cG396s9vkE4TaCfijI3dJbkZu9V99k3/3T9mcfxDpsy9yY+Poh4XHUgL8/CP5ddHT2offNNRLZhu/gpy8KgAbZ//W0fLdbvNMh1h7/5GR0TNOTQEAKr1/ZGHoGVGTjy7zU//IRNF9yKEOwHU7ryhK9JYMs/HBorcKHbpTOAAvenaJox4pABWgAXSAITAD1sABuILd6Dj7gxCUdQw4AA6BVJAJjoN8cBqUgnJQBa6A66AONIF74AF4DPrAM/ASXSsT4COYAwtgBYIgPESCmCAOiA8SgaQgBUgN0oIMIQvIDnKFPCA/KBSKgg5AyVAmdAI6DZ2DqqFrUAN0D3oE9UMvoHfQDPQNWoYRmAZmhnlgUVgWVoN1YXPYAd4F+8F74Tg4BT4GF8Jl8GX4NnwPfgw/g0fhj/A8AhBqhBURQKQRNUQfsUbcEF+EgiQgGUgBUobUII3oTD9FRpFZZAmDwzBh+DHS6Ho1wThivDB7MQmYLMxpTBXmNuY+5inmHWYO8wtLwnJjpbDbsaZYF6wfNgabii3AVmJvYTvQPTWBXcDhcKw4MZwqulddcYG4/bgsXAmuFteK68eN4ebxeDwHXgqvibfGk/GR+FT8KfxlfAt+AD+B/0mgJvARFAhGBDdCKCGJUEC4SGgmDBCmCCtEeqIIcTvRmuhNjCVmEyuIjcRe4gRxhYqBSoxKk8qBKpDqEFUhVQ1VB9Urqu/U1NSC1OrUttQB1InUhdRXqR9Sv6NeomGkkaTRp3GniaI5RnOBppXmBc13EokkStIhuZEiScdI1aR20hvST1omWhlaU1pv2oO0RbS3aQdoP9MR6UTodOl208XRFdDdoOulm6Un0ovS69OT6RPoi+gb6Ifp5xmYGOQZrBlCGLIYLjI8YphmxDOKMhoyejOmMJYztjOOMSFMQkz6TF5MyUwVTB1ME8w4ZjFmU+ZA5kzmK8w9zHMsjCxKLE4s+1iKWO6yjLIirKKspqzBrNms11mHWJfZeNh02XzY0tlq2AbYFtm52HXYfdgz2GvZn7Evc/BzGHIEceRw1HG85sRwSnLacsZwnuHs4JzlYubS4PLiyuC6zjXCDXNLcttx7+cu5+7mnufh5THmCec5xdPOM8vLyqvDG8ibx9vMO8PHxKfFF8CXx9fC94GfhV+XP5i/kP8+/5wAt4CJQJTAOYEegRVBMUFHwSTBWsHXQlRCakK+QnlCbUJzwnzClsIHhC8Jj4gQRdRE/EVOinSKLIqKiTqLHhGtE50WYxczFYsTuyT2Spwkri2+V7xMfFACJ6EmESRRItEnCUsqS/pLFkn2SsFSKlIBUiVS/duw29S3hW4r2zYsTSOtKx0tfUn6nQyrjIVMkkydzGdZYVk32RzZTtlfcspywXIVci/lGeXN5JPkG+W/KUgqeCkUKQwqkhSNFA8q1it+VZJS8lE6o/RcmUnZUvmIcpvymoqqCkWlRmVGVVjVQ7VYdViNWc1GLUvtoTpWXU/9oHqT+tJ2le2R269v/6IhrRGkcVFjeofYDp8dFTvGNAU1yZrnNEe1+LU8tM5qjWoLaJO1y7Tf6wjpeOtU6kzpSugG6l7W/awnp0fRu6W3qL9dP16/1QAxMDbIMOgxZDR0NDxt+MZI0MjP6JLRnLGy8X7jVhOsiblJjsmwKY+pl2m16ZyZqlm82X1zGnN789Pm7y0kLSgWjZawpZllruUrKxGrUKs6a2Btap1r/dpGzGavzR1bnK2NbZHtpJ283QG7Tnsm+z32F+0XHPQcsh1eOoo7Rjm2OdE5uTtVOy06GzifcB51kXWJd3nsyuka4Frvhndzcqt0m99puDN/54S7snuq+9AusV37dj3azbk7ePfdPXR7yHtueGA9nD0ueqySrcll5HlPU89izzkvfa+TXh+9dbzzvGd8NH1O+Ez5avqe8J320/TL9Zvx1/Yv8J8N0A84HfA10CSwNHAxyDroQtB6sHNwbQghxCOkIZQxNCj0fhhv2L6w/nCp8NTw0b3b9+bvnaOYUyojoIhdEfWRzOgjuztKPOpw1Ltoreii6J8xTjE39jHsC93XHSsZmx47FWcUd34/Zr/X/rYDAgcOHXgXrxt/LgFK8ExoOyh0MOXgRKJxYtUhqkNBh54kySWdSPqR7JzcmMKTkpgydtj48KVU2lRK6vARjSOlaZi0gLSedMX0U+m/MrwzujLlMgsyV7O8srqOyh8tPLp+zPdYT7ZK9pnjuOOhx4dytHOqTjCciDsxlmuZezuPPy8j70f+nvxHBUoFpSepTkadHC20KKw/JXzq+KnV0/6nnxXpFdUWcxenFy+WeJcMnNE5U1PKU5pZunw24Ozzc8bnbpeJlhWU48qjyycrnCo6z6udr67krMysXLsQemG0yq7qfrVqdfVF7ovZl+BLUZdmLrtf7rticKW+RrrmXC1rbeZVcDXq6odrHteGrptfb7uhdqPmpsjN4ltMtzJuQ7djb8/V+deN1rvW9zeYNbQ1ajTeuiNz50KTQFPRXZa72c1UzSnN6y1xLfOt4a2z9/zujbXtaXvZ7tI+eN/2fk+HecfDB0YP2jt1O1seaj5serT9UUOXWlfdY5XHt7uVu289UX5yq0el53avam99n3pfY/+O/uYB7YF7Tw2ePhg0HXz8zOpZ/5Dj0PNh9+HR597Pp18Ev/g6Ej2y8jLxFfZVxmv61wVvuN+UvZV4WzuqMnr3ncG77vf271+OeY19HI8YX51ImSRNFkzxTVVPK0w3zRjN9H3Y+WHiY/jHldnUTwyfij+Lf775RedL95zL3MRXytf1b1nfOb5f+KH0o23eZv7NQsjCymLGT46fVUtqS53LzstTKzGr+NXCNYm1xl/mv16th6yvh5Mp5M2nAIJm2NcXgG8XACC5AsDUh74pdm7FZr8Tgj4+YLR0gmSgj/B9JBljj9XBieE5CexEPipNaiuaINJx2ga6WQZpRh+mcuYxVkm2WPYWTjouZ+4Knu98O/hTBJ4IMQjbiRwVfSwOJBQlfaVObuuSXpQVl7OVT1S4pPhMGVaRV92llqF+e/u7HSRNNS0P7XSda7qv9AkGKoZeRseN603emEHmwhbGloFW2dY3bZ7b/rRndVB0tHYKcT7qUuP62O3dzjn3xV0re4AHFZnDU9pL19vOZ4+vjx/Z3z5gRyB/EBQ0GtwScjY0Ocw/3GavGoU/ghDxJXIoqjm6KiZ3X0JscJzrftMDmvGqCSoH1RN1D5knOSf7pEQePpyad6Qi7UZ6a0Z35lDW26NTxz5lfzs+n7NwYj53Pm+5AHOSpXDbKePTXkUHiwtLas60lD4+O3hupGy0fKbiRyVygaVKslrvovulmMt5V67X9Nd+vcZwXfGG/c2IW8dvV9c11t9raG9svXOn6dbd2ubqlvLWknv5bRntB+4Hdtg/UOlk71x6OPqot+vB4/bue0+aemp7C/si+vUHSANPnxYN+j5THsIODQ9XPY9+oTOCG+lE15fyq6nXOW803oy9PTqqMfrxXel7uzFkrHbccXxpIm9y22TLlN3U+PThGdmZ8Q9VH0NnFWfnP9V+9vrC8OXWnM3c5NcD39i+Pfie/SN0nrzgi66j8eWONZn19c35F4KuwoGIAjKNuYZNxLngNQnSRDEqMWpBGjnSdlpbOi/6BIZSxmamGRZ6VjU2Mnsax03ON9zUPIq8O/kS+c8JtAi+FJoXoRblE1MWN5XwkIyVyt12TbpbZloOIy+gsEPRTSlSOVOlQrVB7Yn6++0/duA0ubTktS11gnWz9a7q9xl8MiIY85gomBqaOZp7WYRa7rNKsE62OWybapdmn+GQ5ZjhlOIc6+Lv6uBmsFPb3WiX2+6YPfkeV8ltnl1eHd63fIp99/s5+8sF0ATMBvYFNQZXhxSFZoclhVP2ulN0IvgiViKfRV2JTo3x3GcYKxcnvJ/nAEc8SwL9QdzBhcT3h7qSriXnp8Qc3pVqdsQgzSKdnHEo83zWg6Nvjn3Onj++mDN/4nvuXN6n/NmCzyd/nqI/rV4UWlxZ0nNmrHTm7MS5t2UvyvsrHp5vrmy60FX16aLApV2Xi6+8qGW+anUtDT29lm7J3PauK6ofaMTeUWrac/dwc2VLU2vzvYttx9vj78d0JD7I7ix5WP7oTNexx1Hd9k+kezA9I73X+zL7AwdsnxoOGj6zHfIcjnqe8uLISPxL31f6rzlfz75peHtk1OWd9HvC+8mx9vGSib2TOlM0U4PT5TMHPwR89J71/xTyOfxL+Fz4V8q36O+xP2LmAxaMF+kWb/w0/Pl4yW3p03LfKs3ayOb8S4H7kDn0HPZBcEg2RgrTi43DyeJm8OcJ/kRZ4hJVF3UpTQzJjlaBjpZugf4FQytjNVMuczyLH6sdmya7BAcLxyrnNNcAdzNPDW85XxF/gUCeYLZQqnC0CFnUUIxf7Kd4t0SpZISUyTYBaVh6RmZY9qFco/xFhULFRCUPZXUVnEqvar6aizqH+ovtJRreOxQ0cZpvtG5rZ+v46xroierTGwCD74ZTRkPGd0wKTH3MRMxGzQstrC3xlu1WydamNuw2H2yb7XLt/R00HEmOb5yuOB9wMXNlcX3rVrUzDL3/l3bd3Z24R9+D4NFPLvYM8trhTeM94nPBd6+fmt+qf0tAYqBOEAhqDT4Uoh+KCe0IOxyuG/5z7yWKK3pnV0daR/6IKozeEf0mJnEfz767sR5xrHEj+y8dSI53SRBPWDjYnph7yC/JIFkyhf0wdSpI/XFkLO1Jem1GViY5S+ko/ujIsavZGceDcoxPMJ54kLszdzYvLl+3QO9k2inC6Yyi8RKOMwql6mfVzymXyZaLVwic56hkuEBVRaymQ1eS5mWPK0dqrtQ+vbp6XfyG280Tt/rrmOtdG4obh5uwdyWajVs8Ww/eO9PW3P72/voDgU79h36PsrquPR7qXuuR6N3Zd7L/zVOFwaPPPg/bP28YEXiZ/1r2Le27mPHM6dhPVt8Wlmw35n/rN7qNhFMBIBeNM52OonkGgJw6NM68AwAbFQA2JAAc1AF8pAbAxjUACjr89/6A0MCTgMacrIAPSAAlNNK0AG5o3LwPpKMR5WXQDAbAJFiFGCEJSAeNDyOgo2g82AGNwRAsAOvB3vARNMobgJcRIcQSiUOqkGEMAbMdE4Ipx7zAMmLN0YisHQfhdHCJuDY8Fm+GP45/ThAgBBMaiHiiM7GKuExlSXWOapHairqKBkPjSdNOEiGlkz7TOtA2oZFODj2g30s/zuDK0MtoxHiXSY3pNvN25nYWO5Yx1ig2HFsBuyh7PYcVxzRnGpc81xh3KY8nrxTvT74H/PkC3oJKQjihl8I3RLJFg8XMxaUkSBJzks+k7mw7I50g4y6rLscsNyf/ROGiYrqSv7KZiowqi+q62if1N9sHNLp2dGje1+rU7tEZ0Z3WWzAAhjj0nCOYEEyJZjTmzBYClkpWVtahNnm2TXYTDiRHJSdX53iXs6733abcqXfJ7Xbac8Cjgtzj+dNb2Mfe97Bfk/9yoH7QqeClUK+wgb1GlKZIpajaGOl91+J27O+LDzvInTiUlJdicXjhSF76toyOLJ9jLNlvc57kvs5fL+Q/rV5scWbP2diysxUjF6Srz16Wqxm9du7m7jrqhpqmXS1SbXwdRg/Luml6xfsXBnOGxV/0vzrz9uT7gUmPmaVPjF8ufwM/5BbUF9eXMpbrVwZX76yV/wpfV908P6DN3xwYARcQBQpAG1gCdxACEkAOqAANoBdMgDWIFZKFzCBfKBkqg+5B72EMLAZbwBT4NNwOf0G4EXPkAFKLjGM4MXaYTEwHFsJqYvdj72BXcdq4ZNwjPD3eFX8e/42gS8glTBI1iLnEWSojdM5XqV2ob6KRMIVmkKROOktLTbuPdorOla6H3oi+lUGLoYVRn7GLyZ7pNRqZLrNks0qyPmbby87KfpvDlmOSM5aLxFXBrcM9zpPDa8ZHy/ea/4bAMcEAIT1hduGPIndFj4v5iutJiEgyShG2YaUJMrSyjHIM8gT5JYVpxWGlLuV7KvdUu9Reqn/ToN0hp2mrFaAdqUPR9ddz0Tc2UDdUMlIzNjbZY5pgds6802LOisva0CYIvdPy7E865DvmOZ11bnH56qa8M9H9yW7ePZEevZ5CXr7e+T63fHv8xv1XAlmDFIMdQqJDT4e1hn+gsEUYRUZHXYge2UcfaxmXvf95vGhC/MGxQ37J9CldqZFpuPQjmZistGNc2e05Sbku+fonNU5pFGmUqJdKnMOUPaiIruS6cLfa8xLL5dc1HVd7r8/fkq870PC4ia7ZoJXSVnl/plPv0fVu+Z7ivtcDPwa/Dk09HxuZfvXjLfSOaox5QnjKZKZgVvVLxvfKxeClnpWU1fa1H7+WNucfRnc/A+AF0kAL2AJfEA8KwFXQDT5AREgKsoQoUCHUCn2AWWEDOBKuhEcQBsQUSUFakTWMBiYO04hZxepiM7DDOAncIdxrvBa+jEAghBEGierEEiqYKpDqGbUB9R0adZp7JBvSJG0SnQBdK707/QLDcUZpxidMocwk5ioWPZZXrLFsvGw97Mc4PDn1uCS5mblXeF7z1vOd4A8RsBCUE2IXxgkviXwV/SL2XXxNklZKeJuOtIdMomyJXL38U4XvSpzKpipJqu3qNNvdNa5q4tG3arOuoF6uAathjbGbKYNZv8VpqzAbRzsF+xFHN6duFxPXpzt93X/uTvaAyOGez7xVfYr9iP6HAqmCykMsw0B4HSUskjeqPSYq1nv/54SKxNhDQ0mrKfBhQir9EcW0iPTBTMesmWNpx2VyXuSm5WsUfC2sPr27mKrkQqnq2btl2uWt5w0qu6psqgcvOVzuqzGqbbgmfv3kTcKt+Nur9emNonf67ia1qLTOtBXft36A6bzzKOKxVPd4z5k+lwHmpwPPsofNnq+PXH5l/Xr6bdTo2vukcWQiaQqeTv6A+Xhw9vNnoy+xcyVfj36L+m7wffHHxXmr+ZcL/gsLi9GLMz/df/Yu6S9dWiYthy8PrCivFK58XTVdLVtdWXNYu/IL+eXy6/I6tO64fnFj/iN8FRU2rw+IRg8A7Jv19e+iAOBPALCWs76+Ura+vlaOBhuvAGgN3vrfZ/OuoQeg+O0G6pJs/a8/cP4H0nzQDydFMaoAAAICaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJYTVAgQ29yZSA1LjQuMCI+CiAgIDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIgogICAgICAgICAgICB4bWxuczp0aWZmPSJodHRwOi8vbnMuYWRvYmUuY29tL3RpZmYvMS4wLyI+CiAgICAgICAgIDxleGlmOlBpeGVsWURpbWVuc2lvbj4zMjwvZXhpZjpQaXhlbFlEaW1lbnNpb24+CiAgICAgICAgIDxleGlmOlBpeGVsWERpbWVuc2lvbj4zNTwvZXhpZjpQaXhlbFhEaW1lbnNpb24+CiAgICAgICAgIDx0aWZmOk9yaWVudGF0aW9uPjE8L3RpZmY6T3JpZW50YXRpb24+CiAgICAgIDwvcmRmOkRlc2NyaXB0aW9uPgogICA8L3JkZjpSREY+CjwveDp4bXBtZXRhPgq6myypAAADF0lEQVRIDbVXXUgUURS+d1x/dtOycC0hih6EQog0CiKjgupBepSeIvrBhyIhsIcSoiWzLKi3XirLwFIsiYgEkerFp8W2Il0V0q1WdHc29/9/Zud0ZmV2x92Z2V3Ngbvn3O9853x77ty5O0vICi5HLznpfEUeAwAtNJ0pNGFxpPEcpeQ9AdLiGig/U2h+QYIRx/AOnh19JokAH+rxTZg2SfN8bN6CuHxMyHJjOLNobLzrTSFLm7dgYPZtU8Jjrs0UBD561PPlysFMXG2e103HDooXh/b4Et7veqVCjE7nrTrFGSmlvFJcjuXVYXC2/4KamFhM4PlKv/nSRXlhNT9nh2C36/9+OxEW/JOpGrRkfdIHLkAIwBLOMKT6mHU9Ne5EUP3K2WEwMtImFxNLGZt9yVFSfThdWRCI5+f9B2lA2dMUBGDLo5OdHcqp2Shne94CIWtNdiSNaAoGpgavC8GZNDuXh8vrtXS80KKpCgK4KmJTd9u1kpVicXvf8Sj7NevxkbiqggFr3zUh/Efi5W9xD4UnbvepHQaKgsDivVtBd9K34uYH94ZY825pLreKgn5n91WILsh5Bfux8VuKXWYJ4lIYYtMPbxaskJHAOz7sCi+MNmTAJEvQ96PjMsRcmbwVzaNWU1aXOnklm81WFh+rvyfHVuPzzo+1vt+f6rGGRaqzrMONi09OQ9wrxVRtIvSLiAMSUVWOFOCnTb3yHZs6SxHUuV4bgsBFSiXy/7KGxqG6iu1NVrFeqkPvWFvTWoiJIhGr6aloxSspiN0x3Myj7iUo96ex2YOHt4cUGxtzk5EBbvMB98zANpGcFPSZWxsgEavKKxtJtKRyaTDL9pxmemLyTpdISN5DR7/OTBP8Ps0MWbBk85HkjPNYCMT9soi2q9vfu4Gyn89ugfme1R0r2jqpKC2va6XsS9KO521nCl1bJ8JAUdH5tdVYVl1PwT6gd8++O0QZWg8CqSUUtmLHVQyhlQLAOnzLLsOUUrQ6/H0tQj/1KCHGISa+qUVwhHAEcbgx34MxlgJx4r8BJwFhHvfqHDHUzP0DuLxHRZEPXaYAAAAASUVORK5CYII=')", t.backgroundSize = "100%", e.style.border = "none", e.style.backgroundImage = "none"))
    }, n.prototype.set_mark = function(e, r, t) {
        this.cm.setBookmark({
            line: e,
            ch: r
        }, {
            widget: t,
            handleMouseEvents: !0
        })
    }, n.prototype.render = function(e, r, t, a, i) {
        var n = t.text.indexOf(a, e.next);
        e.next = n + a.length;
        var o = "";
        if (i && "-" == a[0] && (o = a.match(/^-(webkit|o|moz)?-/gi)[0]), this.has_marker(r, n)) return this.update_element(this.create_marker(r, n), a), void this.set_state(r, n, a);
        var s = this.create_marker(r, n);
        s.__isGradient = i, s.__prefix = o, this.update_element(s, a), this.set_state(r, n, a, a), this.set_mark(r, n, s)
    }
}(CodeMirror);          