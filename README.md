# RIDE X — Etapas 2 e 3

Aplicação web com autenticação Supabase e persistência PostgreSQL de atividades e bicicletas. Pedaladas de usuários autenticados são gravadas pelo cliente Supabase, com validação e autorização no PostgreSQL por constraints e Row Level Security (RLS). O modo de teste sem login salva somente no navegador.

## Variáveis de ambiente

Crie `.env.local` a partir de `.env.example`:

| Variável | Obrigatória | Uso |
| --- | --- | --- |
| `VITE_SUPABASE_URL` | Sim | URL do projeto Supabase (`https://<project-ref>.supabase.co`). |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | Sim | Chave pública publishable do projeto. É exposta ao navegador e protegida por RLS. |

Nunca use `service_role`, chaves secretas ou credenciais PostgreSQL no navegador ou em variáveis `VITE_*`. Configure as URLs de redirecionamento de autenticação no painel Supabase para a URL de desenvolvimento e para o domínio de produção.

## Configuração local

1. Instale Node.js 20+ e as dependências com `npm install`.
2. Copie `.env.example` para `.env.local` e preencha as duas variáveis com os valores em **Project Settings → API** no Supabase.
3. Aplique o esquema ao projeto:

   ```powershell
   npx supabase login
   npx supabase link --project-ref <project-ref>
   npx supabase db push
   ```

   Alternativamente, execute o conteúdo da migração em `supabase/migrations/` no SQL Editor do Supabase.
4. Inicie com `npm run dev`. Para validar o pacote de produção use `npm run build`.
5. Cadastre-se na aplicação. Se o projeto exigir confirmação por e-mail, confirme o endereço antes de entrar.

## Publicar no GitHub Pages

O workflow `.github/workflows/deploy-pages.yml` compila e publica automaticamente a aplicação no GitHub Pages a cada push para `main`. O build usa a URL do projeto e a chave `publishable` pública, que é necessária no frontend. Depois que o primeiro deploy terminar, o endereço deste repositório será `https://esleycontapessoal-afk.github.io/ride-x/`.

No painel do Supabase, adicione esse endereço em **Authentication → URL Configuration → Redirect URLs** se for usar login pelo site publicado. GitHub Pages serve por HTTPS, requisito para o GPS no celular; ao abrir o site, permita localização precisa e mantenha a tela ativa durante a pedalada. Não existe configuração que garanta 100% de precisão: a precisão depende do aparelho, do céu/sinal, dos obstáculos e das condições do ambiente, e o navegador só informa uma estimativa.

## Testar uma pedalada sem login

O botão flutuante **Iniciar pedal** permite testar a gravação GPS sem criar conta. A tela mostra velocidade atual, distância, velocidade média, tempo e o percurso no mapa em tempo real. Ao finalizar, a atividade e seus pontos ficam no `localStorage` deste navegador e aparecem no histórico local do dashboard.

Esse modo é apenas para teste: os dados não são enviados ao Supabase, não ficam sincronizados entre dispositivos e podem ser apagados ao limpar os dados do navegador. Para persistência na conta, entre no Supabase antes de iniciar a pedalada. A geolocalização precisa de permissão e funciona em HTTPS ou `localhost`.

## Dados e segurança

- `activities`: registrar, listar, editar, remover, iniciar e encerrar atividades.
- `bicycles`: cadastrar, listar, editar e remover bicicletas.
- As tabelas têm constraints para validar conteúdo, limites numéricos e consistência temporal diretamente no servidor.
- RLS e `auth.uid()` restringem cada operação ao proprietário; o `user_id` não é aceito de outro usuário nem nas atualizações.
- Usuários excluídos têm seus dados pessoais removidos pela FK `ON DELETE CASCADE`.
- Não há dados de demonstração gravados no banco. Operações de conta, bicicletas e atividades manuais exigem sessão autenticada; a gravação GPS também pode ser testada sem login no modo local descrito acima.

## Gravação de pedaladas e GPX (Etapa 3)

Depois de aplicar todas as migrações, entre na conta e use **Iniciar pedal**. A primeira posição só inicia uma pedalada após autorização e leitura GPS válida. A tela de gravação oferece pausar, retomar e finalizar; pontos e estado são sincronizados com `activities` e `activity_points`. A lista de atividades abre o mapa interativo Leaflet do percurso salvo.

- A localização do navegador requer HTTPS ou `localhost` e permissão explícita. Precisão pior que 50 m, coordenadas inválidas, leituras antigas, deslocamentos abaixo do limite de ruído GPS e saltos acima de 45 m/s são descartados. A precisão exibida é a estimativa reportada pelo aparelho, não uma garantia de exatidão.
- A distância é calculada por Haversine entre pontos aceitos. Ganho de elevação soma apenas diferenças positivas de altitude efetivamente fornecida; se não houver altitude, não se estima.
- O botão **Importar GPX** aceita `.gpx` de até 10 MB e até 20.000 pontos de trilha/rota. Coordenadas, horário e altitude só são usados quando presentes e válidos no arquivo. Se a gravação dos pontos falhar, a aplicação tenta excluir a atividade parcial e mostra o erro.
- Se a página recarregar, a atividade em aberto e pontos já sincronizados podem ser recuperados; pontos pendentes de envio são mantidos localmente para tentativa de sincronização posterior.
- Navegadores e sistemas operacionais podem suspender ou encerrar geolocalização quando a aba está em segundo plano, o aparelho bloqueia ou o navegador é fechado. A aplicação avisa dessa limitação, mas não promete gravação contínua nem consegue reconstruir pontos perdidos.
- O mapa depende de conexão com a internet para carregar os tiles do OpenStreetMap. A gravação GPS e o envio dos pontos também requerem conectividade para persistência no Supabase.
