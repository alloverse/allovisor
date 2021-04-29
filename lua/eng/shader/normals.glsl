mat3 cotangent_frame( vec3 N, vec3 p, vec2 uv ) {
    // get edge vec­tors of the pix­el tri­an­gle
    vec3 dp1 = dFdx( p );
    vec3 dp2 = dFdy( p );
    vec2 duv1 = dFdx( uv );
    vec2 duv2 = dFdy( uv );

    // solve the lin­ear sys­tem
    vec3 dp2perp = cross( dp2, N );
    vec3 dp1perp = cross( N, dp1 );
    vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;

    // con­struct a scale-invari­ant frame
    float invmax = inversesqrt( max( dot(T,T), dot(B,B) ) );
    return mat3( T * invmax, B * invmax, N );
}

vec3 perturb_normal( vec3 N, vec3 V, vec2 texcoord ) {
    vec3 map = texture( lovrNormalTexture, texcoord ).xyz;
    map = map * 255./127. - 128./127.;
    //map.y = -map.y;
    mat3 TBN = cotangent_frame( N, V, texcoord );
    return normalize( TBN * map );
}