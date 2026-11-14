import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}});
const base64Url=(bytes:Uint8Array)=>btoa(String.fromCharCode(...bytes)).replaceAll('+','-').replaceAll('/','_').replaceAll('=','');
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response('ok',{headers:cors});if(request.method!=='POST')return json({error:'Method not allowed'},405);
 const authorization=request.headers.get('Authorization');if(!authorization)return json({error:'Sign in is required.'},401);
 const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:authorization}}});
 const {data:{user},error:authError}=await db.auth.getUser();if(authError||!user)return json({error:'Sign in is required.'},401);
 const {documentId,organisationId}=await request.json();if(typeof documentId!=='string'||typeof organisationId!=='string')return json({error:'A document and organisation are required.'},400);
 const {data:doc,error}=await db.from('documents').select('object_key,cloudinary_resource_type,cloudinary_version,cloudinary_format').eq('id',documentId).eq('organisation_id',organisationId).single();
 if(error||!doc)return json({error:'Document not found or access denied.'},404);
 if(!doc.cloudinary_resource_type||!doc.cloudinary_version)return json({error:'This document does not have Cloudinary access details.'},400);
 const cloud=Deno.env.get('CLOUDINARY_CLOUD_NAME'),secret=Deno.env.get('CLOUDINARY_API_SECRET');if(!cloud||!secret)return json({error:'Cloudinary is not configured.'},500);
 const resource=doc.cloudinary_resource_type;const path=`v${doc.cloudinary_version}/${doc.object_key}${resource==='raw'?'':doc.cloudinary_format?`.${doc.cloudinary_format}`:''}`;
 const digest=await crypto.subtle.digest('SHA-1',new TextEncoder().encode(`${path}${secret}`));const signature=base64Url(new Uint8Array(digest)).slice(0,8);
 const url=`https://res.cloudinary.com/${cloud}/${resource}/authenticated/s--${signature}--/${path}`;
 return json({url});
});
