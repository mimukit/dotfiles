var Tn=Object.create;var q=Object.defineProperty,En=Object.defineProperties,In=Object.getOwnPropertyDescriptor,Pn=Object.getOwnPropertyDescriptors,An=Object.getOwnPropertyNames,Ae=Object.getOwnPropertySymbols,Cn=Object.getPrototypeOf,_e=Object.prototype.hasOwnProperty,_n=Object.prototype.propertyIsEnumerable;var Ce=(e,t,n)=>t in e?q(e,t,{enumerable:!0,configurable:!0,writable:!0,value:n}):e[t]=n,f=(e,t)=>{for(var n in t||(t={}))_e.call(t,n)&&Ce(e,n,t[n]);if(Ae)for(var n of Ae(t))_n.call(t,n)&&Ce(e,n,t[n]);return e},v=(e,t)=>En(e,Pn(t)),Ge=e=>q(e,"__esModule",{value:!0});var c=(e,t)=>()=>(t||e((t={exports:{}}).exports,t),t.exports),Gn=(e,t)=>{for(var n in t)q(e,n,{get:t[n],enumerable:!0})},Oe=(e,t,n,r)=>{if(t&&typeof t=="object"||typeof t=="function")for(let o of An(t))!_e.call(e,o)&&(n||o!=="default")&&q(e,o,{get:()=>t[o],enumerable:!(r=In(t,o))||r.enumerable});return e},Re=(e,t)=>Oe(Ge(q(e!=null?Tn(Cn(e)):{},"default",!t&&e&&e.__esModule?{get:()=>e.default,enumerable:!0}:{value:e,enumerable:!0})),e),On=(e=>(t,n)=>e&&e.get(t)||(n=Oe(Ge({}),t,1),e&&e.set(t,n),n))(typeof WeakMap!="undefined"?new WeakMap:0);var ke=c((No,Be)=>{Be.exports=$e;$e.sync=Nn;var Ne=require("fs");function Rn(e,t){var n=t.pathExt!==void 0?t.pathExt:process.env.PATHEXT;if(!n||(n=n.split(";"),n.indexOf("")!==-1))return!0;for(var r=0;r<n.length;r++){var o=n[r].toLowerCase();if(o&&e.substr(-o.length).toLowerCase()===o)return!0}return!1}function qe(e,t,n){return!e.isSymbolicLink()&&!e.isFile()?!1:Rn(t,n)}function $e(e,t,n){Ne.stat(e,function(r,o){n(r,r?!1:qe(o,e,t))})}function Nn(e,t){return qe(Ne.statSync(e),e,t)}});var Ue=c((qo,je)=>{je.exports=Fe;Fe.sync=qn;var Le=require("fs");function Fe(e,t,n){Le.stat(e,function(r,o){n(r,r?!1:Me(o,t))})}function qn(e,t){return Me(Le.statSync(e),t)}function Me(e,t){return e.isFile()&&$n(e,t)}function $n(e,t){var n=e.mode,r=e.uid,o=e.gid,s=t.uid!==void 0?t.uid:process.getuid&&process.getuid(),i=t.gid!==void 0?t.gid:process.getgid&&process.getgid(),a=parseInt("100",8),l=parseInt("010",8),d=parseInt("001",8),p=a|l,g=n&d||n&l&&o===i||n&a&&r===s||n&p&&s===0;return g}});var Xe=c((Bo,De)=>{var $o=require("fs"),U;process.platform==="win32"||global.TESTING_WINDOWS?U=ke():U=Ue();De.exports=ne;ne.sync=Bn;function ne(e,t,n){if(typeof t=="function"&&(n=t,t={}),!n){if(typeof Promise!="function")throw new TypeError("callback not provided");return new Promise(function(r,o){ne(e,t||{},function(s,i){s?o(s):r(i)})})}U(e,t||{},function(r,o){r&&(r.code==="EACCES"||t&&t.ignoreErrors)&&(r=null,o=!1),n(r,o)})}function Bn(e,t){try{return U.sync(e,t||{})}catch(n){if(t&&t.ignoreErrors||n.code==="EACCES")return!1;throw n}}});var Qe=c((ko,Ye)=>{var P=process.platform==="win32"||process.env.OSTYPE==="cygwin"||process.env.OSTYPE==="msys",He=require("path"),kn=P?";":":",We=Xe(),Ke=e=>Object.assign(new Error(`not found: ${e}`),{code:"ENOENT"}),ze=(e,t)=>{let n=t.colon||kn,r=e.match(/\//)||P&&e.match(/\\/)?[""]:[...P?[process.cwd()]:[],...(t.path||process.env.PATH||"").split(n)],o=P?t.pathExt||process.env.PATHEXT||".EXE;.CMD;.BAT;.COM":"",s=P?o.split(n):[""];return P&&e.indexOf(".")!==-1&&s[0]!==""&&s.unshift(""),{pathEnv:r,pathExt:s,pathExtExe:o}},Ve=(e,t,n)=>{typeof t=="function"&&(n=t,t={}),t||(t={});let{pathEnv:r,pathExt:o,pathExtExe:s}=ze(e,t),i=[],a=d=>new Promise((p,g)=>{if(d===r.length)return t.all&&i.length?p(i):g(Ke(e));let h=r[d],b=/^".*"$/.test(h)?h.slice(1,-1):h,x=He.join(b,e),w=!b&&/^\.[\\\/]/.test(e)?e.slice(0,2)+x:x;p(l(w,d,0))}),l=(d,p,g)=>new Promise((h,b)=>{if(g===o.length)return h(a(p+1));let x=o[g];We(d+x,{pathExt:s},(w,I)=>{if(!w&&I)if(t.all)i.push(d+x);else return h(d+x);return h(l(d,p,g+1))})});return n?a(0).then(d=>n(null,d),n):a(0)},Ln=(e,t)=>{t=t||{};let{pathEnv:n,pathExt:r,pathExtExe:o}=ze(e,t),s=[];for(let i=0;i<n.length;i++){let a=n[i],l=/^".*"$/.test(a)?a.slice(1,-1):a,d=He.join(l,e),p=!l&&/^\.[\\\/]/.test(e)?e.slice(0,2)+d:d;for(let g=0;g<r.length;g++){let h=p+r[g];try{if(We.sync(h,{pathExt:o}))if(t.all)s.push(h);else return h}catch{}}}if(t.all&&s.length)return s;if(t.nothrow)return null;throw Ke(e)};Ye.exports=Ve;Ve.sync=Ln});var oe=c((Lo,re)=>{"use strict";var Ze=(e={})=>{let t=e.env||process.env;return(e.platform||process.platform)!=="win32"?"PATH":Object.keys(t).reverse().find(r=>r.toUpperCase()==="PATH")||"Path"};re.exports=Ze;re.exports.default=Ze});var nt=c((Fo,tt)=>{"use strict";var Je=require("path"),Fn=Qe(),Mn=oe();function et(e,t){let n=e.options.env||process.env,r=process.cwd(),o=e.options.cwd!=null,s=o&&process.chdir!==void 0&&!process.chdir.disabled;if(s)try{process.chdir(e.options.cwd)}catch{}let i;try{i=Fn.sync(e.command,{path:n[Mn({env:n})],pathExt:t?Je.delimiter:void 0})}catch{}finally{s&&process.chdir(r)}return i&&(i=Je.resolve(o?e.options.cwd:"",i)),i}function jn(e){return et(e)||et(e,!0)}tt.exports=jn});var rt=c((Mo,ie)=>{"use strict";var se=/([()\][%!^"`<>&|;, *?])/g;function Un(e){return e=e.replace(se,"^$1"),e}function Dn(e,t){return e=`${e}`,e=e.replace(/(\\*)"/g,'$1$1\\"'),e=e.replace(/(\\*)$/,"$1$1"),e=`"${e}"`,e=e.replace(se,"^$1"),t&&(e=e.replace(se,"^$1")),e}ie.exports.command=Un;ie.exports.argument=Dn});var st=c((jo,ot)=>{"use strict";ot.exports=/^#!(.*)/});var at=c((Uo,it)=>{"use strict";var Xn=st();it.exports=(e="")=>{let t=e.match(Xn);if(!t)return null;let[n,r]=t[0].replace(/#! ?/,"").split(" "),o=n.split("/").pop();return o==="env"?r:r?`${o} ${r}`:o}});var ut=c((Do,ct)=>{"use strict";var ae=require("fs"),Hn=at();function Wn(e){let n=Buffer.alloc(150),r;try{r=ae.openSync(e,"r"),ae.readSync(r,n,0,150,0),ae.closeSync(r)}catch{}return Hn(n.toString())}ct.exports=Wn});var pt=c((Xo,ft)=>{"use strict";var Kn=require("path"),lt=nt(),dt=rt(),zn=ut(),Vn=process.platform==="win32",Yn=/\.(?:com|exe)$/i,Qn=/node_modules[\\/].bin[\\/][^\\/]+\.cmd$/i;function Zn(e){e.file=lt(e);let t=e.file&&zn(e.file);return t?(e.args.unshift(e.file),e.command=t,lt(e)):e.file}function Jn(e){if(!Vn)return e;let t=Zn(e),n=!Yn.test(t);if(e.options.forceShell||n){let r=Qn.test(t);e.command=Kn.normalize(e.command),e.command=dt.command(e.command),e.args=e.args.map(s=>dt.argument(s,r));let o=[e.command].concat(e.args).join(" ");e.args=["/d","/s","/c",`"${o}"`],e.command=process.env.comspec||"cmd.exe",e.options.windowsVerbatimArguments=!0}return e}function er(e,t,n){t&&!Array.isArray(t)&&(n=t,t=null),t=t?t.slice(0):[],n=Object.assign({},n);let r={command:e,args:t,options:n,file:void 0,original:{command:e,args:t}};return n.shell?r:Jn(r)}ft.exports=er});var St=c((Ho,ht)=>{"use strict";var ce=process.platform==="win32";function ue(e,t){return Object.assign(new Error(`${t} ${e.command} ENOENT`),{code:"ENOENT",errno:"ENOENT",syscall:`${t} ${e.command}`,path:e.command,spawnargs:e.args})}function tr(e,t){if(!ce)return;let n=e.emit;e.emit=function(r,o){if(r==="exit"){let s=mt(o,t,"spawn");if(s)return n.call(e,"error",s)}return n.apply(e,arguments)}}function mt(e,t){return ce&&e===1&&!t.file?ue(t.original,"spawn"):null}function nr(e,t){return ce&&e===1&&!t.file?ue(t.original,"spawnSync"):null}ht.exports={hookChildProcess:tr,verifyENOENT:mt,verifyENOENTSync:nr,notFoundError:ue}});var xt=c((Wo,A)=>{"use strict";var gt=require("child_process"),le=pt(),de=St();function bt(e,t,n){let r=le(e,t,n),o=gt.spawn(r.command,r.args,r.options);return de.hookChildProcess(o,r),o}function rr(e,t,n){let r=le(e,t,n),o=gt.spawnSync(r.command,r.args,r.options);return o.error=o.error||de.verifyENOENTSync(o.status,r),o}A.exports=bt;A.exports.spawn=bt;A.exports.sync=rr;A.exports._parse=le;A.exports._enoent=de});var yt=c((Ko,wt)=>{"use strict";wt.exports=e=>{let t=typeof e=="string"?`
`:`
`.charCodeAt(),n=typeof e=="string"?"\r":"\r".charCodeAt();return e[e.length-1]===t&&(e=e.slice(0,e.length-1)),e[e.length-1]===n&&(e=e.slice(0,e.length-1)),e}});var Et=c((zo,B)=>{"use strict";var $=require("path"),vt=oe(),Tt=e=>{e=f({cwd:process.cwd(),path:process.env[vt()],execPath:process.execPath},e);let t,n=$.resolve(e.cwd),r=[];for(;t!==n;)r.push($.join(n,"node_modules/.bin")),t=n,n=$.resolve(n,"..");let o=$.resolve(e.cwd,e.execPath,"..");return r.push(o),r.concat(e.path).join($.delimiter)};B.exports=Tt;B.exports.default=Tt;B.exports.env=e=>{e=f({env:process.env},e);let t=f({},e.env),n=vt({env:t});return e.path=t[n],t[n]=B.exports(e),t}});var Pt=c((Vo,fe)=>{"use strict";var It=(e,t)=>{for(let n of Reflect.ownKeys(t))Object.defineProperty(e,n,Object.getOwnPropertyDescriptor(t,n));return e};fe.exports=It;fe.exports.default=It});var Ct=c((Yo,X)=>{"use strict";var or=Pt(),D=new WeakMap,At=(e,t={})=>{if(typeof e!="function")throw new TypeError("Expected a function");let n,r=0,o=e.displayName||e.name||"<anonymous>",s=function(...i){if(D.set(s,++r),r===1)n=e.apply(this,i),e=null;else if(t.throw===!0)throw new Error(`Function \`${o}\` can only be called once`);return n};return or(s,e),D.set(s,r),s};X.exports=At;X.exports.default=At;X.exports.callCount=e=>{if(!D.has(e))throw new Error(`The given function \`${e.name}\` is not wrapped by the \`onetime\` package`);return D.get(e)}});var _t=c(H=>{"use strict";Object.defineProperty(H,"__esModule",{value:!0});H.SIGNALS=void 0;var sr=[{name:"SIGHUP",number:1,action:"terminate",description:"Terminal closed",standard:"posix"},{name:"SIGINT",number:2,action:"terminate",description:"User interruption with CTRL-C",standard:"ansi"},{name:"SIGQUIT",number:3,action:"core",description:"User interruption with CTRL-\\",standard:"posix"},{name:"SIGILL",number:4,action:"core",description:"Invalid machine instruction",standard:"ansi"},{name:"SIGTRAP",number:5,action:"core",description:"Debugger breakpoint",standard:"posix"},{name:"SIGABRT",number:6,action:"core",description:"Aborted",standard:"ansi"},{name:"SIGIOT",number:6,action:"core",description:"Aborted",standard:"bsd"},{name:"SIGBUS",number:7,action:"core",description:"Bus error due to misaligned, non-existing address or paging error",standard:"bsd"},{name:"SIGEMT",number:7,action:"terminate",description:"Command should be emulated but is not implemented",standard:"other"},{name:"SIGFPE",number:8,action:"core",description:"Floating point arithmetic error",standard:"ansi"},{name:"SIGKILL",number:9,action:"terminate",description:"Forced termination",standard:"posix",forced:!0},{name:"SIGUSR1",number:10,action:"terminate",description:"Application-specific signal",standard:"posix"},{name:"SIGSEGV",number:11,action:"core",description:"Segmentation fault",standard:"ansi"},{name:"SIGUSR2",number:12,action:"terminate",description:"Application-specific signal",standard:"posix"},{name:"SIGPIPE",number:13,action:"terminate",description:"Broken pipe or socket",standard:"posix"},{name:"SIGALRM",number:14,action:"terminate",description:"Timeout or timer",standard:"posix"},{name:"SIGTERM",number:15,action:"terminate",description:"Termination",standard:"ansi"},{name:"SIGSTKFLT",number:16,action:"terminate",description:"Stack is empty or overflowed",standard:"other"},{name:"SIGCHLD",number:17,action:"ignore",description:"Child process terminated, paused or unpaused",standard:"posix"},{name:"SIGCLD",number:17,action:"ignore",description:"Child process terminated, paused or unpaused",standard:"other"},{name:"SIGCONT",number:18,action:"unpause",description:"Unpaused",standard:"posix",forced:!0},{name:"SIGSTOP",number:19,action:"pause",description:"Paused",standard:"posix",forced:!0},{name:"SIGTSTP",number:20,action:"pause",description:'Paused using CTRL-Z or "suspend"',standard:"posix"},{name:"SIGTTIN",number:21,action:"pause",description:"Background process cannot read terminal input",standard:"posix"},{name:"SIGBREAK",number:21,action:"terminate",description:"User interruption with CTRL-BREAK",standard:"other"},{name:"SIGTTOU",number:22,action:"pause",description:"Background process cannot write to terminal output",standard:"posix"},{name:"SIGURG",number:23,action:"ignore",description:"Socket received out-of-band data",standard:"bsd"},{name:"SIGXCPU",number:24,action:"core",description:"Process timed out",standard:"bsd"},{name:"SIGXFSZ",number:25,action:"core",description:"File too big",standard:"bsd"},{name:"SIGVTALRM",number:26,action:"terminate",description:"Timeout or timer",standard:"bsd"},{name:"SIGPROF",number:27,action:"terminate",description:"Timeout or timer",standard:"bsd"},{name:"SIGWINCH",number:28,action:"ignore",description:"Terminal window size changed",standard:"bsd"},{name:"SIGIO",number:29,action:"terminate",description:"I/O is available",standard:"other"},{name:"SIGPOLL",number:29,action:"terminate",description:"Watched event",standard:"other"},{name:"SIGINFO",number:29,action:"ignore",description:"Request for process information",standard:"other"},{name:"SIGPWR",number:30,action:"terminate",description:"Device running out of power",standard:"systemv"},{name:"SIGSYS",number:31,action:"core",description:"Invalid system call",standard:"other"},{name:"SIGUNUSED",number:31,action:"terminate",description:"Invalid system call",standard:"other"}];H.SIGNALS=sr});var pe=c(C=>{"use strict";Object.defineProperty(C,"__esModule",{value:!0});C.SIGRTMAX=C.getRealtimeSignals=void 0;var ir=function(){let e=Ot-Gt+1;return Array.from({length:e},ar)};C.getRealtimeSignals=ir;var ar=function(e,t){return{name:`SIGRT${t+1}`,number:Gt+t,action:"terminate",description:"Application-specific signal (realtime)",standard:"posix"}},Gt=34,Ot=64;C.SIGRTMAX=Ot});var Rt=c(W=>{"use strict";Object.defineProperty(W,"__esModule",{value:!0});W.getSignals=void 0;var cr=require("os"),ur=_t(),lr=pe(),dr=function(){let e=(0,lr.getRealtimeSignals)();return[...ur.SIGNALS,...e].map(fr)};W.getSignals=dr;var fr=function({name:e,number:t,description:n,action:r,forced:o=!1,standard:s}){let{signals:{[e]:i}}=cr.constants,a=i!==void 0;return{name:e,number:a?i:t,description:n,supported:a,action:r,forced:o,standard:s}}});var qt=c(_=>{"use strict";Object.defineProperty(_,"__esModule",{value:!0});_.signalsByNumber=_.signalsByName=void 0;var pr=require("os"),Nt=Rt(),mr=pe(),hr=function(){return(0,Nt.getSignals)().reduce(Sr,{})},Sr=function(e,{name:t,number:n,description:r,supported:o,action:s,forced:i,standard:a}){return v(f({},e),{[t]:{name:t,number:n,description:r,supported:o,action:s,forced:i,standard:a}})},gr=hr();_.signalsByName=gr;var br=function(){let e=(0,Nt.getSignals)(),t=mr.SIGRTMAX+1,n=Array.from({length:t},(r,o)=>xr(o,e));return Object.assign({},...n)},xr=function(e,t){let n=wr(e,t);if(n===void 0)return{};let{name:r,description:o,supported:s,action:i,forced:a,standard:l}=n;return{[e]:{name:r,number:e,description:o,supported:s,action:i,forced:a,standard:l}}},wr=function(e,t){let n=t.find(({name:r})=>pr.constants.signals[r]===e);return n!==void 0?n:t.find(r=>r.number===e)},yr=br();_.signalsByNumber=yr});var Bt=c((ts,$t)=>{"use strict";var{signalsByName:vr}=qt(),Tr=({timedOut:e,timeout:t,errorCode:n,signal:r,signalDescription:o,exitCode:s,isCanceled:i})=>e?`timed out after ${t} milliseconds`:i?"was canceled":n!==void 0?`failed with ${n}`:r!==void 0?`was killed with ${r} (${o})`:s!==void 0?`failed with exit code ${s}`:"failed",Er=({stdout:e,stderr:t,all:n,error:r,signal:o,exitCode:s,command:i,escapedCommand:a,timedOut:l,isCanceled:d,killed:p,parsed:{options:{timeout:g}}})=>{s=s===null?void 0:s,o=o===null?void 0:o;let h=o===void 0?void 0:vr[o].description,b=r&&r.code,w=`Command ${Tr({timedOut:l,timeout:g,errorCode:b,signal:o,signalDescription:h,exitCode:s,isCanceled:d})}: ${i}`,I=Object.prototype.toString.call(r)==="[object Error]",M=I?`${w}
${r.message}`:w,j=[M,t,e].filter(Boolean).join(`
`);return I?(r.originalMessage=r.message,r.message=j):r=new Error(j),r.shortMessage=M,r.command=i,r.escapedCommand=a,r.exitCode=s,r.signal=o,r.signalDescription=h,r.stdout=e,r.stderr=t,n!==void 0&&(r.all=n),"bufferedData"in r&&delete r.bufferedData,r.failed=!0,r.timedOut=Boolean(l),r.isCanceled=d,r.killed=p&&!l,r};$t.exports=Er});var Lt=c((ns,me)=>{"use strict";var K=["stdin","stdout","stderr"],Ir=e=>K.some(t=>e[t]!==void 0),kt=e=>{if(!e)return;let{stdio:t}=e;if(t===void 0)return K.map(r=>e[r]);if(Ir(e))throw new Error(`It's not possible to provide \`stdio\` in combination with one of ${K.map(r=>`\`${r}\``).join(", ")}`);if(typeof t=="string")return t;if(!Array.isArray(t))throw new TypeError(`Expected \`stdio\` to be of type \`string\` or \`Array\`, got \`${typeof t}\``);let n=Math.max(t.length,K.length);return Array.from({length:n},(r,o)=>t[o])};me.exports=kt;me.exports.node=e=>{let t=kt(e);return t==="ipc"?"ipc":t===void 0||typeof t=="string"?[t,t,t,"ipc"]:t.includes("ipc")?t:[...t,"ipc"]}});var Ft=c((rs,z)=>{z.exports=["SIGABRT","SIGALRM","SIGHUP","SIGINT","SIGTERM"];process.platform!=="win32"&&z.exports.push("SIGVTALRM","SIGXCPU","SIGXFSZ","SIGUSR2","SIGTRAP","SIGSYS","SIGQUIT","SIGIOT");process.platform==="linux"&&z.exports.push("SIGIO","SIGPOLL","SIGPWR","SIGSTKFLT","SIGUNUSED")});var Xt=c((os,R)=>{var u=global.process;typeof u!="object"||!u?R.exports=function(){}:(Mt=require("assert"),G=Ft(),jt=/^win/i.test(u.platform),k=require("events"),typeof k!="function"&&(k=k.EventEmitter),u.__signal_exit_emitter__?m=u.__signal_exit_emitter__:(m=u.__signal_exit_emitter__=new k,m.count=0,m.emitted={}),m.infinite||(m.setMaxListeners(1/0),m.infinite=!0),R.exports=function(e,t){if(global.process===u){Mt.equal(typeof e,"function","a callback must be provided for exit handler"),O===!1&&he();var n="exit";t&&t.alwaysLast&&(n="afterexit");var r=function(){m.removeListener(n,e),m.listeners("exit").length===0&&m.listeners("afterexit").length===0&&V()};return m.on(n,e),r}},V=function(){!O||global.process!==u||(O=!1,G.forEach(function(t){try{u.removeListener(t,Y[t])}catch{}}),u.emit=Q,u.reallyExit=Se,m.count-=1)},R.exports.unload=V,T=function(t,n,r){m.emitted[t]||(m.emitted[t]=!0,m.emit(t,n,r))},Y={},G.forEach(function(e){Y[e]=function(){if(u===global.process){var n=u.listeners(e);n.length===m.count&&(V(),T("exit",null,e),T("afterexit",null,e),jt&&e==="SIGHUP"&&(e="SIGINT"),u.kill(u.pid,e))}}}),R.exports.signals=function(){return G},O=!1,he=function(){O||u!==global.process||(O=!0,m.count+=1,G=G.filter(function(t){try{return u.on(t,Y[t]),!0}catch{return!1}}),u.emit=Dt,u.reallyExit=Ut)},R.exports.load=he,Se=u.reallyExit,Ut=function(t){u===global.process&&(u.exitCode=t||0,T("exit",u.exitCode,null),T("afterexit",u.exitCode,null),Se.call(u,u.exitCode))},Q=u.emit,Dt=function(t,n){if(t==="exit"&&u===global.process){n!==void 0&&(u.exitCode=n);var r=Q.apply(this,arguments);return T("exit",u.exitCode,null),T("afterexit",u.exitCode,null),r}else return Q.apply(this,arguments)});var Mt,G,jt,k,m,V,T,Y,O,he,Se,Ut,Q,Dt});var Wt=c((ss,Ht)=>{"use strict";var Pr=require("os"),Ar=Xt(),Cr=1e3*5,_r=(e,t="SIGTERM",n={})=>{let r=e(t);return Gr(e,t,n,r),r},Gr=(e,t,n,r)=>{if(!Or(t,n,r))return;let o=Nr(n),s=setTimeout(()=>{e("SIGKILL")},o);s.unref&&s.unref()},Or=(e,{forceKillAfterTimeout:t},n)=>Rr(e)&&t!==!1&&n,Rr=e=>e===Pr.constants.signals.SIGTERM||typeof e=="string"&&e.toUpperCase()==="SIGTERM",Nr=({forceKillAfterTimeout:e=!0})=>{if(e===!0)return Cr;if(!Number.isFinite(e)||e<0)throw new TypeError(`Expected the \`forceKillAfterTimeout\` option to be a non-negative integer, got \`${e}\` (${typeof e})`);return e},qr=(e,t)=>{e.kill()&&(t.isCanceled=!0)},$r=(e,t,n)=>{e.kill(t),n(Object.assign(new Error("Timed out"),{timedOut:!0,signal:t}))},Br=(e,{timeout:t,killSignal:n="SIGTERM"},r)=>{if(t===0||t===void 0)return r;let o,s=new Promise((a,l)=>{o=setTimeout(()=>{$r(e,n,l)},t)}),i=r.finally(()=>{clearTimeout(o)});return Promise.race([s,i])},kr=({timeout:e})=>{if(e!==void 0&&(!Number.isFinite(e)||e<0))throw new TypeError(`Expected the \`timeout\` option to be a non-negative integer, got \`${e}\` (${typeof e})`)},Lr=async(e,{cleanup:t,detached:n},r)=>{if(!t||n)return r;let o=Ar(()=>{e.kill()});return r.finally(()=>{o()})};Ht.exports={spawnedKill:_r,spawnedCancel:qr,setupTimeout:Br,validateTimeout:kr,setExitHandler:Lr}});var zt=c((is,Kt)=>{"use strict";var y=e=>e!==null&&typeof e=="object"&&typeof e.pipe=="function";y.writable=e=>y(e)&&e.writable!==!1&&typeof e._write=="function"&&typeof e._writableState=="object";y.readable=e=>y(e)&&e.readable!==!1&&typeof e._read=="function"&&typeof e._readableState=="object";y.duplex=e=>y.writable(e)&&y.readable(e);y.transform=e=>y.duplex(e)&&typeof e._transform=="function";Kt.exports=y});var Yt=c((as,Vt)=>{"use strict";var{PassThrough:Fr}=require("stream");Vt.exports=e=>{e=f({},e);let{array:t}=e,{encoding:n}=e,r=n==="buffer",o=!1;t?o=!(n||r):n=n||"utf8",r&&(n=null);let s=new Fr({objectMode:o});n&&s.setEncoding(n);let i=0,a=[];return s.on("data",l=>{a.push(l),o?i=a.length:i+=l.length}),s.getBufferedValue=()=>t?a:r?Buffer.concat(a,i):a.join(""),s.getBufferedLength=()=>i,s}});var Qt=c((cs,L)=>{"use strict";var{constants:Mr}=require("buffer"),jr=require("stream"),{promisify:Ur}=require("util"),Dr=Yt(),Xr=Ur(jr.pipeline),ge=class extends Error{constructor(){super("maxBuffer exceeded");this.name="MaxBufferError"}};async function be(e,t){if(!e)throw new Error("Expected a stream");t=f({maxBuffer:1/0},t);let{maxBuffer:n}=t,r=Dr(t);return await new Promise((o,s)=>{let i=a=>{a&&r.getBufferedLength()<=Mr.MAX_LENGTH&&(a.bufferedData=r.getBufferedValue()),s(a)};(async()=>{try{await Xr(e,r),o()}catch(a){i(a)}})(),r.on("data",()=>{r.getBufferedLength()>n&&i(new ge)})}),r.getBufferedValue()}L.exports=be;L.exports.buffer=(e,t)=>be(e,v(f({},t),{encoding:"buffer"}));L.exports.array=(e,t)=>be(e,v(f({},t),{array:!0}));L.exports.MaxBufferError=ge});var Jt=c((us,Zt)=>{"use strict";var{PassThrough:Hr}=require("stream");Zt.exports=function(){var e=[],t=new Hr({objectMode:!0});return t.setMaxListeners(0),t.add=n,t.isEmpty=r,t.on("unpipe",o),Array.prototype.slice.call(arguments).forEach(n),t;function n(s){return Array.isArray(s)?(s.forEach(n),this):(e.push(s),s.once("end",o.bind(null,s)),s.once("error",t.emit.bind(t,"error")),s.pipe(t,{end:!1}),this)}function r(){return e.length==0}function o(s){e=e.filter(function(i){return i!==s}),!e.length&&t.readable&&t.end()}}});var rn=c((ls,nn)=>{"use strict";var tn=zt(),en=Qt(),Wr=Jt(),Kr=(e,t)=>{t===void 0||e.stdin===void 0||(tn(t)?t.pipe(e.stdin):e.stdin.end(t))},zr=(e,{all:t})=>{if(!t||!e.stdout&&!e.stderr)return;let n=Wr();return e.stdout&&n.add(e.stdout),e.stderr&&n.add(e.stderr),n},xe=async(e,t)=>{if(!!e){e.destroy();try{return await t}catch(n){return n.bufferedData}}},we=(e,{encoding:t,buffer:n,maxBuffer:r})=>{if(!(!e||!n))return t?en(e,{encoding:t,maxBuffer:r}):en.buffer(e,{maxBuffer:r})},Vr=async({stdout:e,stderr:t,all:n},{encoding:r,buffer:o,maxBuffer:s},i)=>{let a=we(e,{encoding:r,buffer:o,maxBuffer:s}),l=we(t,{encoding:r,buffer:o,maxBuffer:s}),d=we(n,{encoding:r,buffer:o,maxBuffer:s*2});try{return await Promise.all([i,a,l,d])}catch(p){return Promise.all([{error:p,signal:p.signal,timedOut:p.timedOut},xe(e,a),xe(t,l),xe(n,d)])}},Yr=({input:e})=>{if(tn(e))throw new TypeError("The `input` option cannot be a stream in sync mode")};nn.exports={handleInput:Kr,makeAllStream:zr,getSpawnedResult:Vr,validateInputSync:Yr}});var sn=c((ds,on)=>{"use strict";var Qr=(async()=>{})().constructor.prototype,Zr=["then","catch","finally"].map(e=>[e,Reflect.getOwnPropertyDescriptor(Qr,e)]),Jr=(e,t)=>{for(let[n,r]of Zr){let o=typeof t=="function"?(...s)=>Reflect.apply(r.value,t(),s):r.value.bind(t);Reflect.defineProperty(e,n,v(f({},r),{value:o}))}return e},eo=e=>new Promise((t,n)=>{e.on("exit",(r,o)=>{t({exitCode:r,signal:o})}),e.on("error",r=>{n(r)}),e.stdin&&e.stdin.on("error",r=>{n(r)})});on.exports={mergePromise:Jr,getSpawnedPromise:eo}});var un=c((fs,cn)=>{"use strict";var an=(e,t=[])=>Array.isArray(t)?[e,...t]:[e],to=/^[\w.-]+$/,no=/"/g,ro=e=>typeof e!="string"||to.test(e)?e:`"${e.replace(no,'\\"')}"`,oo=(e,t)=>an(e,t).join(" "),so=(e,t)=>an(e,t).map(n=>ro(n)).join(" "),io=/ +/g,ao=e=>{let t=[];for(let n of e.trim().split(io)){let r=t[t.length-1];r&&r.endsWith("\\")?t[t.length-1]=`${r.slice(0,-1)} ${n}`:t.push(n)}return t};cn.exports={joinCommand:oo,getEscapedCommand:so,parseCommand:ao}});var Sn=c((ps,N)=>{"use strict";var co=require("path"),ye=require("child_process"),uo=xt(),lo=yt(),fo=Et(),po=Ct(),Z=Bt(),dn=Lt(),{spawnedKill:mo,spawnedCancel:ho,setupTimeout:So,validateTimeout:go,setExitHandler:bo}=Wt(),{handleInput:xo,getSpawnedResult:wo,makeAllStream:yo,validateInputSync:vo}=rn(),{mergePromise:ln,getSpawnedPromise:To}=sn(),{joinCommand:fn,parseCommand:pn,getEscapedCommand:mn}=un(),Eo=1e3*1e3*100,Io=({env:e,extendEnv:t,preferLocal:n,localDir:r,execPath:o})=>{let s=t?f(f({},process.env),e):e;return n?fo.env({env:s,cwd:r,execPath:o}):s},hn=(e,t,n={})=>{let r=uo._parse(e,t,n);return e=r.command,t=r.args,n=r.options,n=f({maxBuffer:Eo,buffer:!0,stripFinalNewline:!0,extendEnv:!0,preferLocal:!1,localDir:n.cwd||process.cwd(),execPath:process.execPath,encoding:"utf8",reject:!0,cleanup:!0,all:!1,windowsHide:!0},n),n.env=Io(n),n.stdio=dn(n),process.platform==="win32"&&co.basename(e,".exe")==="cmd"&&t.unshift("/q"),{file:e,args:t,options:n,parsed:r}},F=(e,t,n)=>typeof t!="string"&&!Buffer.isBuffer(t)?n===void 0?void 0:"":e.stripFinalNewline?lo(t):t,J=(e,t,n)=>{let r=hn(e,t,n),o=fn(e,t),s=mn(e,t);go(r.options);let i;try{i=ye.spawn(r.file,r.args,r.options)}catch(b){let x=new ye.ChildProcess,w=Promise.reject(Z({error:b,stdout:"",stderr:"",all:"",command:o,escapedCommand:s,parsed:r,timedOut:!1,isCanceled:!1,killed:!1}));return ln(x,w)}let a=To(i),l=So(i,r.options,a),d=bo(i,r.options,l),p={isCanceled:!1};i.kill=mo.bind(null,i.kill.bind(i)),i.cancel=ho.bind(null,i,p);let h=po(async()=>{let[{error:b,exitCode:x,signal:w,timedOut:I},M,j,vn]=await wo(i,r.options,d),Te=F(r.options,M),Ee=F(r.options,j),Ie=F(r.options,vn);if(b||x!==0||w!==null){let Pe=Z({error:b,exitCode:x,signal:w,stdout:Te,stderr:Ee,all:Ie,command:o,escapedCommand:s,parsed:r,timedOut:I,isCanceled:p.isCanceled,killed:i.killed});if(!r.options.reject)return Pe;throw Pe}return{command:o,escapedCommand:s,exitCode:0,stdout:Te,stderr:Ee,all:Ie,failed:!1,timedOut:!1,isCanceled:!1,killed:!1}});return xo(i,r.options.input),i.all=yo(i,r.options),ln(i,h)};N.exports=J;N.exports.sync=(e,t,n)=>{let r=hn(e,t,n),o=fn(e,t),s=mn(e,t);vo(r.options);let i;try{i=ye.spawnSync(r.file,r.args,r.options)}catch(d){throw Z({error:d,stdout:"",stderr:"",all:"",command:o,escapedCommand:s,parsed:r,timedOut:!1,isCanceled:!1,killed:!1})}let a=F(r.options,i.stdout,i.error),l=F(r.options,i.stderr,i.error);if(i.error||i.status!==0||i.signal!==null){let d=Z({stdout:a,stderr:l,error:i.error,signal:i.signal,exitCode:i.status,command:o,escapedCommand:s,parsed:r,timedOut:i.error&&i.error.code==="ETIMEDOUT",isCanceled:!1,killed:i.signal!==null});if(!r.options.reject)return d;throw d}return{command:o,escapedCommand:s,exitCode:0,stdout:a,stderr:l,failed:!1,timedOut:!1,isCanceled:!1,killed:!1}};N.exports.command=(e,t)=>{let[n,...r]=pn(e);return J(n,r,t)};N.exports.commandSync=(e,t)=>{let[n,...r]=pn(e);return J.sync(n,r,t)};N.exports.node=(e,t,n={})=>{t&&!Array.isArray(t)&&typeof t=="object"&&(n=t,t=[]);let r=dn.node(n),o=process.execArgv.filter(a=>!a.startsWith("--inspect")),{nodePath:s=process.execPath,nodeOptions:i=o}=n;return J(s,[...i,e,...Array.isArray(t)?t:[]],v(f({},n),{stdin:void 0,stdout:void 0,stderr:void 0,stdio:r,shell:!1}))}});var Oo={};Gn(Oo,{default:()=>yn});var S=require("@raycast/api");var gn=Re(require("node:process"),1),bn=Re(Sn(),1);async function ve(e){if(gn.default.platform!=="darwin")throw new Error("macOS only");let{stdout:t}=await(0,bn.default)("osascript",["-e",e]);return t}var te=require("react");var xn=require("url"),wn=(e,t)=>{let n=new xn.URL(t).hostname;return`https://www.google.com/s2/favicons?sz=${e}&domain=${n}`};var ee=class{constructor(t,n,r,o,s){this.title=t;this.url=n;this.favicon=r;this.windowsIndex=o;this.tabIndex=s}static parse(t){let n=t.split(this.TAB_CONTENTS_SEPARATOR);return new ee(n[0],n[1],n[2],+n[3],+n[4])}key(){return`${this.windowsIndex}${ee.TAB_CONTENTS_SEPARATOR}${this.tabIndex}`}urlWithoutScheme(){return this.url.replace(/(^\w+:|^)\/\//,"").replace("www.","")}urlDomain(){return this.urlWithoutScheme().split("/")[0]}googleFavicon(){return wn(64,this.url)}},E=ee;E.TAB_CONTENTS_SEPARATOR="~~~";async function Po(e){return(await ve(`
      set _output to ""
      tell application "Google Chrome"
        set _window_index to 1
        repeat with w in windows
          set _tab_index to 1
          repeat with t in tabs of w
            set _title to get title of t
            set _url to get URL of t
            set _favicon to ${e?`execute of tab _tab_index of window _window_index javascript \xAC
                    "document.head.querySelector('link[rel~=icon]').href;"`:'""'}
            set _output to (_output & _title & "${E.TAB_CONTENTS_SEPARATOR}" & _url & "${E.TAB_CONTENTS_SEPARATOR}" & _favicon & "${E.TAB_CONTENTS_SEPARATOR}" & _window_index & "${E.TAB_CONTENTS_SEPARATOR}" & _tab_index & "\\n")
            set _tab_index to _tab_index + 1
          end repeat
          set _window_index to _window_index + 1
          if _window_index > count windows then exit repeat
        end repeat
      end tell
      return _output
  `)).split(`
`).filter(r=>r.length!==0).map(r=>E.parse(r))}async function Ao(e){await ve(`
    tell application "Google Chrome"
      activate
      set index of window (${e.windowsIndex} as number) to (${e.windowsIndex} as number)
      set active tab index of window (${e.windowsIndex} as number) to (${e.tabIndex} as number)
    end tell
  `)}function yn(){let{useOriginalFavicon:e}=(0,S.getPreferenceValues)(),[t,n]=(0,te.useState)({});return(0,te.useEffect)(()=>{async function r(){n({tabs:await Po(e)})}r()},[]),_jsx(S.List,null,t.tabs?.map(r=>_jsx(Co,{key:r.key(),tab:r,useOriginalFavicon:e})))}function Co(e){return _jsx(S.List.Item,{title:e.tab.title,subtitle:e.tab.urlWithoutScheme(),keywords:[e.tab.urlWithoutScheme()],actions:_jsx(_o,{tab:e.tab}),icon:e.useOriginalFavicon?e.tab.favicon:e.tab.googleFavicon()})}function _o(e){return _jsx(S.ActionPanel,{title:e.tab.title},_jsx(Go,{tab:e.tab}),_jsx(S.CopyToClipboardAction,{title:"Copy URL",content:e.tab.url}))}function Go(e){async function t(){(0,S.closeMainWindow)(),(0,S.popToRoot)(),await Ao(e.tab)}return _jsx(S.ActionPanel.Item,{title:"Open tab",icon:{source:S.Icon.Eye},onAction:t})}module.exports=On(Oo);0&&(module.exports={});