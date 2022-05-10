local vecScreenSize = Vector2( guiGetScreenSize() );

class "CRenderTargetMap"
{
	constructor			= function ( self )
		self.m_pScreenSource	= DxScreenSource( vecScreenSize.x, vecScreenSize.y );
		-- self.m_pScreenMap		= DxRenderTarget( vecScreenSize.x, vecScreenSize.y );
		self.m_pEdgeMap 		= DxRenderTarget( vecScreenSize.x, vecScreenSize.y );
		self.m_pBlendMap 		= DxRenderTarget( vecScreenSize.x, vecScreenSize.y );
		self.m_pNeighborHoodMap = DxRenderTarget( vecScreenSize.x, vecScreenSize.y );
		
		bindEvent( "onClientRender", root, self.OnPreRender, self );
	end;
	
	destructor			= function ( self )
		destroyElement( self.m_pScreenSource );
		destroyElement( self.m_pScreenMap );
		destroyElement( self.m_pEdgeMap );
		destroyElement( self.m_pBlendMap );
		destroyElement( self.m_pNeighborHoodMap );
	end;
	
	GetScreenSource		= function ( self )
		return self.m_pScreenSource;
	end;
	
	-- GetScreenMap		= function ( self )
		-- return self.m_pScreenMap;
	-- end;
	
	GetEdgeMap			= function ( self )
		return self.m_pEdgeMap;
	end;
	
	GetBlendMap			= function ( self )
		return self.m_pBlendMap;
	end;
	
	GetNeighborHoodMap	= function ( self )
		return self.m_pNeighborHoodMap;
	end;
	
	Clear				= function ( self )
		self:GetScreenSource():update( false );
		
		-- self:GetScreenMap():setAsTarget( true );
			-- dxDrawImage( 0, 0, vecScreenSize.x, vecScreenSize.y, self:GetScreenSource() );
		-- dxSetRenderTarget();
		
		self:GetEdgeMap():setAsTarget( true );
		dxSetRenderTarget()
		
		self:GetBlendMap():setAsTarget( true );
		dxSetRenderTarget()
		
		self:GetNeighborHoodMap():setAsTarget( true );
		dxSetRenderTarget()	
	end;
	
	OnPreRender = function ( self )
		self:Clear();
	end;
};

local g_pRenderTargetMap = CRenderTargetMap();

class "CSMAA"
{
	constructor				= function ( self )
		self.m_pAreaTex		= DxTexture( "Textures/AreaTex.dds", "argb", false, "wrap" );
		self.m_pSearchTex	= DxTexture( "Textures/SearchTex.dds", "argb", false, "wrap" );
		
		-- Детектор граней
		self.m_pShaderEdgeDetection = DxShader( "Shaders/SMAAEdgeDetection.fx" );
		
		self.m_pShaderEdgeDetection:setValue( "ScnMap", g_pRenderTargetMap:GetScreenSource() );
		
		self:SetViewPortData( self.m_pShaderEdgeDetection );
		
		-- Грани
		self.m_pShaderBlendingWeight = DxShader( "Shaders/SMAABlendingWeight.fx" );
		
		self.m_pShaderBlendingWeight:setValue( "ScnMap", g_pRenderTargetMap:GetScreenSource() );
		self.m_pShaderBlendingWeight:setValue( "SMAAEdgeMap", g_pRenderTargetMap:GetEdgeMap() );
		self.m_pShaderBlendingWeight:setValue( "SMAAAreaMap", self.m_pAreaTex );
		self.m_pShaderBlendingWeight:setValue( "SMAASearchMap", self.m_pSearchTex );
		
		self:SetViewPortData( self.m_pShaderBlendingWeight );
		
		-- Склейка
		self.m_pShaderNeighborhoodBlending = DxShader( "Shaders/SMAANeighborhoodBlending.fx" );
		
		self.m_pShaderNeighborhoodBlending:setValue( "ScnMap", g_pRenderTargetMap:GetScreenSource() );
		self.m_pShaderNeighborhoodBlending:setValue( "SMAABlendMap", g_pRenderTargetMap:GetBlendMap() );
		
		self:SetViewPortData( self.m_pShaderNeighborhoodBlending );
		
		bindEvent( "onClientRender", root, self.OnPreRender, self );
	end;
	
	destructor				= function ( self )
		destroyElement( self.m_pShaderEdgeDetection );
	end;
	
	SetViewPortData			= function ( self, pShader )
		pShader:setValue( "ViewportSize", vecScreenSize.x, vecScreenSize.y );
		pShader:setValue( "ViewportOffset", 0.5 / vecScreenSize.x, 0.5 / vecScreenSize.y );
		pShader:setValue( "ViewportOffset2", 1 / vecScreenSize.x, 1 / vecScreenSize.y );
	end;
	
	GetShaderEdgeDetection	= function ( self )
		return self.m_pShaderEdgeDetection;
	end;
	
	GetShaderBlendingWeight	= function ( self )
		return self.m_pShaderBlendingWeight;
	end;
	
	GetShaderNeighborhoodBlending	= function ( self )
		return self.m_pShaderNeighborhoodBlending;
	end;
	
	OnPreRender = function ( self )
		g_pRenderTargetMap:GetEdgeMap():setAsTarget( true );
		dxDrawImage( 0, 0, vecScreenSize.x, vecScreenSize.y, self:GetShaderEdgeDetection() );
		dxSetRenderTarget();
		
		g_pRenderTargetMap:GetBlendMap():setAsTarget( true );
		dxDrawImage( 0, 0, vecScreenSize.x, vecScreenSize.y, self:GetShaderBlendingWeight() );
		dxSetRenderTarget();
		
		g_pRenderTargetMap:GetNeighborHoodMap():setAsTarget( true );
		dxDrawImage( 0, 0, vecScreenSize.x, vecScreenSize.y, self:GetShaderNeighborhoodBlending() );
		dxSetRenderTarget();


		--renderDebug()
	
	end;
};

local g_pSMAA = CSMAA();

local DEBUG_X = vecScreenSize.x / 4;
local DEBUG_Y = vecScreenSize.y / 4;

-- Результат
function renderDebug() 
	dxDrawImage( 0, 0, vecScreenSize.x, vecScreenSize.y, g_pRenderTargetMap:GetNeighborHoodMap() );
	
	-- ГРАНИ
	dxDrawRectangle( 0, 0, DEBUG_X, DEBUG_Y, tocolor( 0, 0, 0, 255 ), false );
	dxDrawImage( 0, 0, DEBUG_X, DEBUG_Y, g_pRenderTargetMap:GetEdgeMap() );
	
	-- ГЛУБИНА
	dxDrawRectangle( DEBUG_X, 0, DEBUG_X, DEBUG_Y, tocolor( 0, 0, 0, 255 ), false );
	dxDrawImage( DEBUG_X, 0, DEBUG_X, DEBUG_Y, g_pRenderTargetMap:GetBlendMap() );
	
	-- ОБРАБОТАННОЕ
	dxDrawRectangle( DEBUG_X * 2, 0, DEBUG_X, DEBUG_Y, tocolor( 0, 0, 0, 255 ), false );
	dxDrawImage( DEBUG_X * 2, 0, DEBUG_X, DEBUG_Y, g_pRenderTargetMap:GetNeighborHoodMap() );
end
--[[
addEventHandler( "onClientRender", root, function ( )
	dxDrawImage( 0, 0, vecScreenSize.x, vecScreenSize.y, g_pRenderTargetMap:GetNeighborHoodMap() );
	
	-- ГРАНИ
	dxDrawRectangle( 0, 0, DEBUG_X, DEBUG_Y, tocolor( 0, 0, 0, 255 ), false );
	dxDrawImage( 0, 0, DEBUG_X, DEBUG_Y, g_pRenderTargetMap:GetEdgeMap() );
	
	-- ГЛУБИНА
	dxDrawRectangle( DEBUG_X, 0, DEBUG_X, DEBUG_Y, tocolor( 0, 0, 0, 255 ), false );
	dxDrawImage( DEBUG_X, 0, DEBUG_X, DEBUG_Y, g_pRenderTargetMap:GetBlendMap() );
	
	-- ОБРАБОТАННОЕ
	dxDrawRectangle( DEBUG_X * 2, 0, DEBUG_X, DEBUG_Y, tocolor( 0, 0, 0, 255 ), false );
	dxDrawImage( DEBUG_X * 2, 0, DEBUG_X, DEBUG_Y, g_pRenderTargetMap:GetNeighborHoodMap() );
end );
]]