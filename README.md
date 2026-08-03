# Spring Boot vs Spin (WASM) on MicroK8s

This repository demonstrates running a simple web application using two completely different paradigms on a Kubernetes cluster (MicroK8s):

1. **Spring Boot (Java):** A traditional robust containerized application.
2. **Spin (WASM/Rust):** A lightweight, serverless WebAssembly component deployed via SpinKube.

## Applications

Both applications implement two HTTP endpoints:
- `/hello`: Returns a plain string "Hello, World!"
- `/compute`: Calculates the 35th Fibonacci number recursively (to simulate CPU load).

## Deployment

Run the `deploy.sh` script to set up SpinKube on MicroK8s, build the apps, push them to the local registry, and deploy them. Note: You will need `sudo` for `microk8s` commands.

```bash
./deploy.sh
```

## Comparison Metrics

After deployment, you can observe the following differences:

### 1. Image / Artifact Size
- **Spring Boot:** Typically 100-200MB depending on the JRE base image.
- **Spin (WASM):** Typically a few megabytes (~2-5MB) as it only contains the compiled Wasm module.

## Karşılaştırma Sonuçları ve Analiz

Yapılan 10.000 istekli (`concurrency: 100`) yoğun yük testi (`ab`) sonuçlarına göre elde edilen veriler şunlardır:

### 1. Performans (Hız)
- **Spring Boot:** ~28 İstek/Saniye (Toplam süre: 352 saniye)
- **Spin (WASM):** ~18 İstek/Saniye (Toplam süre: 529 saniye)

*Analiz:* Yoğun CPU gerektiren (saf matematiksel hesaplama olan Fibonacci) sentetik testte Spring Boot'un (Java) daha hızlı çalıştığı görülmüştür. Bunun temel sebebi, Java'nın çalışma zamanında (Runtime) devreye giren JIT (Just-In-Time) derleyicisinin, sürekli tekrarlayan matematiksel döngüleri çok agresif bir şekilde optimize edebilmesidir. WebAssembly (Wasmtime) motoru henüz JIT seviyesinde bir optimizasyon sunmadığı için saf işlemci gücü gerektiren bu spesifik görevde geride kalmıştır.

### 2. Kaynak Tüketimi (CPU ve RAM)
- **Spring Boot:** Pik CPU: `3158m` (3.1 Core) | Pik RAM: `261Mi` (Boşta: ~130Mi)
- **Spin (WASM):** Pik CPU: `3129m` (3.1 Core) | Pik RAM: `87Mi` (Boşta: ~0Mi)

*Analiz:* Spin (WebAssembly) mimarisinin asıl parladığı nokta kaynak tüketimi olmuştur. Spring Boot boşta bile 130 MB civarı bellek tüketirken, Spin boştayken ölçülemeyecek kadar az (neredeyse sıfır) kaynak tüketmektedir. En ağır yük altında bile Spin uygulaması sadece **87 MB** belleğe ihtiyaç duyarken, Spring Boot **261 MB** belleğe kadar çıkmıştır. 

### 3. Genel Değerlendirme
SpinKube ve WebAssembly, özellikle çok sayıda mikroservisin veya "Serverless" fonksiyonun bir arada çalıştığı ve **bellek maliyetlerinin (RAM)** çok kritik olduğu bulut ortamları için devasa bir tasarruf potansiyeli sunmaktadır. Uygulamalar milisaniyeler içinde uyanıp (Cold start problemi olmadan) işlerini minimum RAM ile halledebilirler. Ancak sadece saf işlemci gücü gerektiren çok yoğun matematiksel hesaplamalarda geleneksel JIT derlemeli diller (Java, C# vb.) şu an için bir miktar performans avantajına sahiptir.

### 4. Development Experience
- **Spring Boot:** Feature-rich ecosystem, easy to test, standard Dockerfile pipeline.
- **Spin:** Instant compilation (with Rust/Go), easy to write serverless-like functions, but requires specific operators (SpinKube/Kwasm) on the Kubernetes cluster.
