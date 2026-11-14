import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
const hex = (bytes: ArrayBuffer) => [...new Uint8Array(bytes)].map(b => b.toString(16).padStart(2, '0')).join('');

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
  const authorization = request.headers.get('Authorization');
  if (!authorization) return json({ error: 'Sign in is required.' }, 401);
  const url = Deno.env.get('SUPABASE_URL')!;
  const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
  const supabase = createClient(url, anon, { global: { headers: { Authorization: authorization } } });
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) return json({ error: 'Sign in is required.' }, 401);

  const { filename, contentType, size, organisationId } = await request.json();
  if (typeof filename !== 'string' || !filename.trim() || typeof organisationId !== 'string' || !Number.isInteger(size) || size <= 0 || size > 10_000_000) return json({ error: 'Provide a file up to 10 MB.' }, 400);
  const { data: membership } = await supabase.from('user_masals').select('id').eq('user_id', user.id).eq('organisation_id', organisationId).maybeSingle();
  if (!membership) return json({ error: 'You do not have access to this organisation.' }, 403);

  const cloud = Deno.env.get('CLOUDINARY_CLOUD_NAME');
  const apiKey = Deno.env.get('CLOUDINARY_API_KEY');
  const secret = Deno.env.get('CLOUDINARY_API_SECRET');
  if (!cloud || !apiKey || !secret) return json({ error: 'Cloudinary is not configured on the server.' }, 500);
  const timestamp = Math.floor(Date.now() / 1000);
  const publicId = `${organisationId}/${crypto.randomUUID()}`;
  const folder = 'mahal-documents';
  const signatureInput = `folder=${folder}&public_id=${publicId}&timestamp=${timestamp}&type=authenticated${secret}`;
  const signature = hex(await crypto.subtle.digest('SHA-1', new TextEncoder().encode(signatureInput)));
  return json({ cloudName: cloud, apiKey, timestamp, signature, folder, publicId, resourceType: contentType?.startsWith('image/') ? 'image' : 'raw', assetType: 'authenticated', originalFilename: filename });
});
