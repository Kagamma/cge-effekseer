#if defined(__ANDROID__)
	#define __cdecl
	#define __EFFEKSEER_RENDERER_GLES2__
#endif
#if defined(__APPLE__)
	#if defined(TARGET_IPHONE_SIMULATOR) && defined(TARGET_OS_IPHONE)
		#define __EFFEKSEER_RENDERER_GLES2__
	#endif
#endif
#if defined(_MSC_VER) || defined(__MINGW32__)
	#define __dllexport __declspec(dllexport)
#else
	#define __dllexport
#endif
#if defined(__GNUC__)
	#define __cdecl __attribute__((__cdecl__))
#endif
#define STB_IMAGE_EFK_IMPLEMENTATION

#include <stdio.h>
#include <string>

#include <Effekseer.h>
#include <EffekseerRendererGL.h>

#include "stb_image_utils.h"

using namespace Effekseer;
using namespace EffekseerRendererGL;
using namespace EffekseerUtils;

// Loader helpers's function pointers

// params: filePath, objPas, data, size
typedef void (*loader_load_t)(const char16_t*, void**, void**, int32_t*);
// params: objPas
typedef void (*loader_free_t)(void*);
// params: filePath, objPas, data, width, height, bpp
typedef void (*loader_loadImageFromFile_t)(const char16_t*, void**, uint8_t**, int32_t*, int32_t*, int32_t*);

loader_load_t loader_load = nullptr;
loader_free_t loader_free = nullptr;
loader_loadImageFromFile_t loader_loadImageFromFile = nullptr;

// Custom Loaders

class CastleFileReader : public FileReader {
private:
	void* objPas;
	void* data;
	int32_t size;
	int32_t position;
public:
	CastleFileReader(const char16_t* path): position(0) {
		loader_load(path, &this->objPas, &this->data, &this->size);
	}

	~CastleFileReader() override {
		loader_free(objPas);
	}

	size_t Read(void* buffer, size_t size) override {
		if (data == nullptr)
			return 0;
		size_t actualSize = this->position + size > this->size - 1 ? this->size - this->position - 1 : size;
		memcpy(buffer, (char*)this->data + this->position, actualSize);
		this->position += actualSize;
		return actualSize;
	}

	void Seek(int position) override {
		this->position = position > this->size - 1 ? this->size - 1 : position;
	}

	int GetPosition() override {
		return data == nullptr ? this->position : -1;
	}

	size_t GetLength() override {
		return this->size;
	}
};

class CastleFileInterface : public FileInterface {
public:
	CastleFileInterface() {};
	~CastleFileInterface() override {};

	FileReader* OpenRead(const char16_t* path) override {
		return new CastleFileReader(path);
	}

	FileWriter* OpenWrite(const char16_t* path) override {
		return nullptr;
	}
};

/**
 * If use internal loader, it cannot handle images with bpp < 4 correctly? This is why this
 * custom texture loader exists :)
**/
class CastleTextureLoader : public TextureLoader {
private:
	Backend::GraphicsDeviceRef graphicsDevice;
public:
	CastleTextureLoader(Backend::GraphicsDeviceRef gd) {
		graphicsDevice = gd;
	}
	virtual ~CastleTextureLoader() = default;

	TextureRef Load(const char16_t* path, TextureType textureType) override	{
		void* data;
		void* objPas;
		int32_t size;
		std::vector<uint8_t> textureData;
		int width;
		int height;
		int bpp;
		uint8_t* pixels;
		//
		if (loader_loadImageFromFile != nullptr) {
			loader_loadImageFromFile(path, &objPas, &pixels, &width, &height, &bpp);
		} else {
			loader_load(path, &objPas, &data, &size);
			pixels = (uint8_t*)stbi_load_from_memory((stbi_uc const*)data, size, &width, &height, &bpp, 0);
			if (data == nullptr) return nullptr;
		}

		textureData.resize(width * height * 4);
		auto buf = textureData.data();

		if (bpp == 4) {
			memcpy(textureData.data(), pixels, width * height * 4);
		} else if (bpp == 2) {
			for (int h = 0; h < height; h++) {
				for (int w = 0; w < width; w++) {
					((uint8_t*)buf)[(w + h * width) * 4 + 0] = pixels[(w + h * width) * 2 + 0];
					((uint8_t*)buf)[(w + h * width) * 4 + 1] = pixels[(w + h * width) * 2 + 0];
					((uint8_t*)buf)[(w + h * width) * 4 + 2] = pixels[(w + h * width) * 2 + 0];
					((uint8_t*)buf)[(w + h * width) * 4 + 3] = pixels[(w + h * width) * 2 + 1];
				}
			}
		} else if (bpp == 1) {
			for (int h = 0; h < height; h++) {
				for (int w = 0; w < width; w++) {
					((uint8_t*)buf)[(w + h * width) * 4 + 0] = pixels[(w + h * width) * 1 + 0];
					((uint8_t*)buf)[(w + h * width) * 4 + 1] = pixels[(w + h * width) * 1 + 0];
					((uint8_t*)buf)[(w + h * width) * 4 + 2] = pixels[(w + h * width) * 1 + 0];
					((uint8_t*)buf)[(w + h * width) * 4 + 3] = 255;
				}
			}
		} else {
			for (int h = 0; h < height; h++) {
				for (int w = 0; w < width; w++) {
					((uint8_t*)buf)[(w + h * width) * 4 + 0] = pixels[(w + h * width) * 3 + 0];
					((uint8_t*)buf)[(w + h * width) * 4 + 1] = pixels[(w + h * width) * 3 + 1];
					((uint8_t*)buf)[(w + h * width) * 4 + 2] = pixels[(w + h * width) * 3 + 2];
					((uint8_t*)buf)[(w + h * width) * 4 + 3] = 255;
				}
			}
		}
		if (loader_loadImageFromFile == nullptr) {
			stbi_image_free(pixels);
		}
		loader_free(objPas);
		// v1.6 detect no mipmap by checking texture file name for "_NoMip"
		std::u16string s = path;
		std::wstring tmp(L"_nomip");
		std::u16string noMipStr(tmp.begin(), tmp.end());
		std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c){ return std::tolower(c); });
		bool isMipMap;
		if (s.find(noMipStr) != std::u16string::npos) {
			isMipMap = false;
		} else {
			isMipMap = true;
		}
		Backend::TextureParameter param;
		param.Size = {width, height};
		param.Format = Backend::TextureFormatType::R8G8B8A8_UNORM;
		param.GenerateMipmap = isMipMap;
		param.InitialData.assign(textureData.data(), textureData.data() + width * height * 4);

		auto texture = MakeRefPtr<Texture>();
		texture->SetBackend(graphicsDevice->CreateTexture(param));

		return texture;
	}
};

extern "C" {

// ----- Loader registers -----

__dllexport void __cdecl EFK_Loader_RegisterLoadRoutine(loader_load_t func) {
	loader_load = func;
}

__dllexport void __cdecl EFK_Loader_RegisterFreeRoutine(loader_free_t func) {
	loader_free = func;
}

__dllexport void __cdecl EFK_Loader_RegisterLoadImageFromFileRoutine(loader_loadImageFromFile_t func) {
	loader_loadImageFromFile = func;
}

// ----- Manager -----

__dllexport Manager* __cdecl EFK_Manager_Create(int maxInstance) {
	auto managerRef = Manager::Create(maxInstance);
	return static_cast<Manager*>(managerRef.Pin());
}

__dllexport void __cdecl EFK_Manager_Destroy(Manager* manager) {
	manager->Release();
}

__dllexport void __cdecl EFK_Manager_SetDefaultRenders(Manager* manager, Renderer* renderer) {
	manager->SetSpriteRenderer(renderer->CreateSpriteRenderer());
	manager->SetRibbonRenderer(renderer->CreateRibbonRenderer());
	manager->SetRingRenderer(renderer->CreateRingRenderer());
	manager->SetTrackRenderer(renderer->CreateTrackRenderer());
	manager->SetModelRenderer(renderer->CreateModelRenderer());
	// TODO: Still doesnt understand much about this
	manager->CreateCullingWorld(1000.0f, 1000.0f, 1000.0f, 1);
}

__dllexport void __cdecl EFK_Manager_SetDefaultLoaders(Manager* manager, Renderer* renderer) {
	if (loader_load != nullptr && loader_free != nullptr) {
	//	manager->SetTextureLoader(EffekseerRenderer::CreateTextureLoader(renderer->GetGraphicsDevice(), new CastleFileInterface(), ColorSpaceType::Gamma));
		manager->SetTextureLoader(TextureLoaderRef(new CastleTextureLoader(renderer->GetGraphicsDevice())));
		manager->SetModelLoader(EffekseerRenderer::CreateModelLoader(renderer->GetGraphicsDevice(), new CastleFileInterface()));
		manager->SetMaterialLoader(CreateMaterialLoader(renderer->GetGraphicsDevice(), new CastleFileInterface()));
		manager->SetCurveLoader(MakeRefPtr<CurveLoader>(new CastleFileInterface()));
	} else {
		manager->SetTextureLoader(renderer->CreateTextureLoader());
		manager->SetModelLoader(renderer->CreateModelLoader());
		manager->SetMaterialLoader(renderer->CreateMaterialLoader());
		manager->SetCurveLoader(MakeRefPtr<CurveLoader>());
	}
}

__dllexport void __cdecl EFK_Manager_Update(Manager* manager, float delta) {
	manager->Update(delta);
}

__dllexport Handle __cdecl EFK_Manager_Play(Manager* manager, Effect* effect, Vector3D* position, int32_t startFrame) {
	auto effectRef = RefPtr<Effect>(effect);
	effectRef.Pin();
	return manager->Play(effectRef, *position, startFrame);
}

__dllexport void __cdecl EFK_Manager_StopEffect(Manager* manager, Handle handle) {
	manager->StopEffect(handle);
}

__dllexport bool __cdecl EFK_Manager_Exists(Manager* manager, Handle handle) {
	return manager->Exists(handle);
}

__dllexport void __cdecl EFK_Manager_SetMatrix(Manager* manager, Handle handle, float m[]) {
	Matrix43 m43;
	m43.Value[0][0] = m[0];
	m43.Value[0][1] = m[1];
	m43.Value[0][2] = m[2];
	m43.Value[1][0] = m[4];
	m43.Value[1][1] = m[5];
	m43.Value[1][2] = m[6];
	m43.Value[2][0] = m[8];
	m43.Value[2][1] = m[9];
	m43.Value[2][2] = m[10];
	m43.Value[3][0] = m[12];
	m43.Value[3][1] = m[13];
	m43.Value[3][2] = m[14];
	manager->SetMatrix(handle, m43);
}

__dllexport void __cdecl EFK_Manager_SetSpeed(Manager* manager, Handle handle, float speed) {
	return manager->SetSpeed(handle, speed);
}

// ----- Renderer -----

__dllexport Renderer* __cdecl EFK_Renderer_Create(int squareMaxCount, OpenGLDeviceType deviceType, bool isExtensionsEnabled) {
	auto rendererRef = Renderer::Create(squareMaxCount, deviceType, isExtensionsEnabled);
	return static_cast<Renderer*>(rendererRef.Pin());
}

__dllexport void __cdecl EFK_Renderer_Destroy(Renderer* renderer) {
	renderer->Release();
}

__dllexport void __cdecl EFK_Renderer_SetViewMatrix(Renderer* renderer, float m[]) {
	Matrix44 m44;
	memcpy(m44.Values, m, sizeof(float) * 16);
	renderer->SetCameraMatrix(m44);
}

__dllexport void __cdecl EFK_Renderer_SetProjectionMatrix(Renderer* renderer, float m[]) {
	Matrix44 m44;
	memcpy(m44.Values, m, sizeof(float) * 16);
	renderer->SetProjectionMatrix(m44);
}

__dllexport void __cdecl EFK_Renderer_Render(Renderer* renderer, Manager* manager) {
	renderer->BeginRendering();
	manager->CalcCulling(renderer->GetCameraProjectionMatrix(), true);
	manager->Draw();
	renderer->EndRendering();
}

__dllexport int32_t __cdecl EFK_Renderer_GetDrawCallCount(Renderer* renderer) {
	int32_t result = renderer->GetDrawCallCount();
	renderer->ResetDrawCallCount();
	return result;
}

// ----- Effect -----

__dllexport Effect* __cdecl EFK_Effect_CreateWithFile(Manager* manager, char16_t* fileName) {
	auto managerRef = RefPtr<Manager>(manager);
	managerRef.Pin();
	auto effectRef = Effect::Create(managerRef, fileName);
	return static_cast<Effect*>(effectRef.Pin());
}

__dllexport Effect* __cdecl EFK_Effect_CreateWithMemory(Manager* manager, void* data, int32_t size, char16_t* materialPath) {
	auto managerRef = RefPtr<Manager>(manager);
	managerRef.Pin();
	auto effectRef = Effect::Create(managerRef, data, size, 1.0f, materialPath);
	return static_cast<Effect*>(effectRef.Pin());
}

__dllexport void __cdecl EFK_Effect_Destroy(Effect* effect) {
	effect->Release();
}

}