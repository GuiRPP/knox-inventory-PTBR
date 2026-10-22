/* The generator window's pictures, cut from the approved mockup (generator_v18.html).
   make_generator.ps1 builds bake.html = the mockup + this script, and Edge without a
   window takes one picture per layer: bake.html#layer=<name>&vb=x,y,w,h&w=<px>&h=<px>.
   Text and everything that moves are left out of the body: the game draws them. */
(function(){
const q=new URLSearchParams(location.hash.slice(1)),layer=q.get('layer')||'under';
const vb=(q.get('vb')||'0,0,700,500').split(',').map(Number),W=+q.get('w')||700,H=+q.get('h')||500;
document.body.style.background='transparent';
const box=document.querySelector('.gbox');box.style.background='transparent';box.style.padding='0';box.style.margin='0';box.style.maxWidth='none';
document.querySelectorAll('.gctl').forEach(e=>e.remove());
g.classList.add('ready');g.style.transition='none';g.style.opacity='1';g.style.width=W+'px';g.style.height=H+'px';
g.setAttribute('viewBox',vb.join(' '));g.setAttribute('preserveAspectRatio','none');
centreG($('can'),[550,66,64,80]);   /* (the mockup does it once its font is in) */
/* (mockup 18 has the tank and the can's place 9 lower, in its group #tank - the author,
   2026-10-22: the same room above the tank as below it. The gauge's marks and needle are
   cut where they were: KnoxGeneratorWindow.lua draws them TANK_DY lower.) */
document.querySelectorAll('text').forEach(t=>t.remove());
/* the pieces drawn over the needles, the digits and the lamps' light */
const over=[];
g.querySelectorAll('circle').forEach(c=>{const x=+c.getAttribute('cx'),y=+c.getAttribute('cy'),r=+c.getAttribute('r');
 if((x==450&&y==104&&r==4)||(x==449&&y==103&&r==1.2)||(x==272&&y==284&&r==8)||(x==270&&y==282&&r==2.5))over.push(c)});
g.querySelectorAll('path').forEach(p=>{const s=p.getAttribute('stroke')||'';if(s.indexOf('glintF')>=0||s.indexOf('glintL')>=0)over.push(p)});
$('lamps').querySelectorAll('circle').forEach(c=>{if(c.getAttribute('r')=='2')over.push(c)});
$('meter').querySelectorAll('rect').forEach(r=>{if(r.getAttribute('opacity')=='0.12'||r.getAttribute('opacity')=='.12'||r.getAttribute('stroke')=='#6a706d')over.push(r)});
/* the plugs (an outlet's children after its socket: the plug's face, its icon, its cable) */
const plugs=[];
Array.from($('outs').children).forEach(o=>{Array.from(o.children).forEach((c,i)=>{if(i>=6)plugs.push(c)})});
const lamps=['lrun','loil','lco'].map($);
const dyn=['fscale','lscale','fneedle','lneedle','knob','lever','lvr','cord','hg','tip','dbg'].map($);
function hide(list){list.forEach(e=>{if(e)e.style.visibility='hidden'})}
function only(list){g.style.visibility='hidden';list.forEach(e=>{if(e)e.style.visibility='visible'})}
function white(list,attr){list.forEach(e=>{e.querySelectorAll('*').forEach(c=>{if(c.getAttribute(attr))c.setAttribute(attr,'#fff')});if(e.getAttribute(attr))e.setAttribute(attr,'#fff')})}
const ticks=Array.from($('fscale').children);
if(layer=='under'){hide(dyn);hide(over);hide(plugs);hide(lamps)}
else if(layer=='over'){only(over)}
else if(layer=='fticks'){$('tank').removeAttribute('transform');only(ticks.slice(1));white(ticks,'stroke')}
else if(layer=='fticks_red'){$('tank').removeAttribute('transform');only(ticks.slice(0,1));white(ticks,'stroke')}
else if(layer=='lticks'){only([$('lscale')]);white([$('lscale')],'stroke')}
else if(layer=='fneedle'||layer=='lneedle'){$('tank').removeAttribute('transform');$(layer).removeAttribute('transform');only([$(layer)])}
else if(layer=='knob'||layer=='knobmark'){const k=$('knob');k.removeAttribute('transform');const mark=k.querySelector('rect[fill="#d4c38a"]');
 if(layer=='knob'){only([k]);mark.style.visibility='hidden'}else{only([mark]);mark.setAttribute('fill','#fff')}}
else if(layer=='lever'){const l=$('lever');l.removeAttribute('transform');only([l]);
 /* sand by the skin: white and greys in the sand's own proportions (#d4c38a, #8a7d52, #b5a672) */
 l.querySelector('circle').setAttribute('fill','#fff');l.querySelector('circle').setAttribute('stroke','#a4a4a4');l.querySelector('rect').setAttribute('fill','#d9d9d9')}
else if(layer=='handle'){const h=$('hg');h.setAttribute('transform','translate(350,250)');only([h])}
else if(layer=='plug'){only(plugs.slice(0,3).filter((c,i)=>i!=1))}
else if(layer=='lampdisc'){const d=$('lrun');d.setAttribute('fill','#fff');only([d])}
else if(layer.indexOf('icon_')==0){const kind=layer.slice(5),grp=el('g',{},g);
 if(kind=='plug'){/* any other appliance: a plug, its two pins */const c='#fff',w=1.4;
  el('rect',{x:-4.5,y:-3,width:9,height:8,rx:2,fill:'none',stroke:c,'stroke-width':w},grp);el('line',{x1:-2,y1:-3,x2:-2,y2:-7,stroke:c,'stroke-width':w},grp);
  el('line',{x1:2,y1:-3,x2:2,y2:-7,stroke:c,'stroke-width':w},grp);el('line',{x1:0,y1:5,x2:0,y2:8,stroke:c,'stroke-width':w},grp);centreG(grp,[501,220,28,26])}
 else{icon(kind,[501,220,28,26],grp)}
 grp.querySelectorAll('*').forEach(c=>{if(c.getAttribute('stroke'))c.setAttribute('stroke','#fff')});only([grp])}
document.title='baked '+layer;
})();
