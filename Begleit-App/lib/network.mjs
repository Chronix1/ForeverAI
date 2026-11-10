import { AppError } from './common.mjs';
export async function request(url, options = {}, fetcher = fetch, timeout = 30000) {
  const signal = options.signal ? AbortSignal.any([options.signal, AbortSignal.timeout(timeout)]) : AbortSignal.timeout(timeout);
  let r;
  try { r = await fetcher(url, { ...options, signal, redirect:'error' }); }
  catch (e) { if (options.signal?.aborted) throw new AppError('cancelled'); throw new AppError(e.name === 'TimeoutError' || signal.aborted ? 'timeout' : 'network_error', 'Network request failed or timed out. Check your connection and endpoint.'); }
  if (!r.ok) {
    // Only use machine-readable upstream error codes. Bodies can contain secrets.
    let code = ''; try { const j = await limitedJSON(r); code = j.error?.code || j.error?.type || j.code || ''; } catch {}
    if (!/^[a-zA-Z0-9_.-]{1,80}$/.test(String(code))) code = '';
    throw new AppError(`http_${r.status}${code ? '_' + code : ''}`, `Provider rejected the request (HTTP ${r.status}${code ? ', ' + code : ''}).`, 400);
  }
  return r;
}
export async function limitedJSON(response, limit=4*1024*1024) {
  if (!response.body) throw new AppError('empty_response');
  const chunks=[]; let size=0;
  for await (const c of response.body) { size+=c.length; if (size>limit) throw new AppError('response_too_large'); chunks.push(c); }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { throw new AppError('invalid_json'); }
}
export async function jsonRequest(url, options={}, fetcher=fetch) {
  return limitedJSON(await request(url, options, fetcher));
}
export async function* readSSE(body) {
  if (!body) throw new AppError('empty_stream');
  const decoder = new TextDecoder(); let buffer='', event='message', data=[], eventSize=0, total=0;
  const lines = function*(input) { let ix; while ((ix = input.indexOf('\n')) >= 0) { yield input.slice(0,ix).replace(/\r$/, ''); input=input.slice(ix+1); } return input; };
  for await (const chunk of body) {
    total+=chunk.length; if (total>16*1024*1024) throw new AppError('stream_too_large');
    buffer+=decoder.decode(chunk,{stream:true});
    let at;
    while ((at=buffer.indexOf('\n'))>=0) {
      const line=buffer.slice(0,at).replace(/\r$/, ''); buffer=buffer.slice(at+1);
      if (!line) {
        if (data.length) yield {event, data:data.join('\n')};
        event='message'; data=[]; eventSize=0;
      } else if (line.startsWith('event:')) event=line.slice(6).trim();
      else if (line.startsWith('data:')) { const v=line.slice(5).replace(/^ /,''); data.push(v); eventSize+=v.length; }
      if (eventSize>2*1024*1024) throw new AppError('event_too_large');
    }
    if (buffer.length>2*1024*1024) throw new AppError('event_too_large');
  }
  // Do not accept a truncated terminal event without its blank-line delimiter.
}
