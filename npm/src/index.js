/**
* Create a new Elm application 
* @param {{
*  node: HTMLElement,
*  init: ({ flags: any, node: HTMLElement }) => any
*  flags: any,
*  onPortNotFound?: (name : string) => any
* }} options 
* @returns {ElmApp}
*/
export function createInertiaApp (options = {}) {
 let pageObject = undefined, xsrfToken = undefined
 
 // Get initial page data from HTML node
 try { pageObject = JSON.parse(options.node.getAttribute('data-page')) }
 catch (err) { console.error('elm-inertia could not find "data-page" attribute:\n\n' + err) }

 // Get XSRF cookie from `document.cookie`
 try { xsrfToken = refreshXsrfToken() }
 catch (err) { console.error('elm-inertia could not get inertia xsrf token:\n\n' + err) }

 // Start up the Elm application
 let elmApp = options.init({
   node: options.node,
   flags: {
     user: options.flags,
     inertia: { pageObject, xsrfToken }
   }
 })

 // Register ports needed for Inertia to work
 let ports = toPorts(elmApp)

 ports.onRefreshXsrfToken.subscribe(() => {
   let xsrfToken = refreshXsrfToken()
   ports.onXsrfTokenRefreshed.send(xsrfToken)
 })

 function refreshXsrfToken () {
   return decodeURIComponent(document.cookie.split(';')
     .map(x => x.split('='))
     .map(([key,value]) => key.trim() === 'XSRF-TOKEN' ? value.trim() : undefined)
     .find(x => x !== ''))
 }

 /**
  * In Elm, a port that is not called won't be defined in the `app.ports` object.
  * 
  * This uses a Proxy to warn us about missing ports in development, and report
  * them to our Error Reporting service in production.
  * 
  * It also prevents the need to add `if` statements throughout port logic to
  * check for the presence of ports to avoid runtime exceptions.
  */
 function toPorts(app) {
   return new Proxy({}, {
     get: (_, name) => new Proxy({}, {
       get: (_, method) => {
         if (typeof app?.ports?.[name]?.[method] === 'function') {
           return app.ports[name][method]
         }
         
         if (options.onPortNotFound) {
           try { options.onPortNotFound(name) } catch (_) {}
         }
   
         return () => {}
       }
     })
   })
 }

 // Return app to user so they can work with ports
 return { ports }
}


const ElmInertia = { createInertiaApp }

export default ElmInertia


/**
* 
* @typedef {{
*  ports: { 
*    [name:string]: {
*      send : (data : unknown) => unknown,
*      subscribe : (fn: (data: unknown) => unknown) => void,
*      unsubscribe : (fn: (data: unknown) => unknown) => void
*    }
*  } 
* }} ElmApp
* 
*/