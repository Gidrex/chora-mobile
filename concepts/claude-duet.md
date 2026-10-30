# Claude Duet — детальный разбор концепта + проекция на chora-mobile

Дата изучения: 2026-10-30. Статус Duet: research preview по waitlist.
Метод: официальные страницы Anthropic (product, announcement 21.10, safety 23.10,
support-статья Get started), инженерные блоги (Managed Agents, auto-mode classifier,
trustworthy agents framework), Academy (Small Business plugin), пресса (TechCrunch,
The Verge, Forbes), независимые тесты (Claire Vo / Lenny's Newsletter, 2 выпуска),
сравнения (Refix, MindStudio, Eigent/CellCog), конкуренты (Meta, OpenAI).
Где факт из вторичного источника, а не от Anthropic — помечено.

---

## 1. TL;DR (30 секунд)

Claude Duet — отдельный апп (iOS / Android / claude.ai), где Claude работает как
проактивный агент, а не как чат, который надо открывать. Формула Anthropic из 4 глаголов:

1. **Приходит сам** — утренний бриф + сообщения, только когда что-то требует внимания.
2. **Берёт задачи** — от «назначь встречу» до «построй дашборд / финмодель / веб-апп».
3. **Работает, пока тебя нет** — своя cloud VM + свой браузер, телефон/ноут можно закрыть.
4. **Спрашивает перед действием** — отправка, оплата, подпись, удаление только с явного апрува.

Модель — Opus 5.5 (релиз 22.09.2026, 1M контекст, adaptive thinking always-on).
Контекст (память, скиллы, коннекторы, чаты) наследуется из обычного Claude-аккаунта.
Доступ: только Pro и Max, только США, waitlist. Team/Enterprise — «позже».
Лимиты — общие с остальным Claude, фоновые проверки их тратят.

Ключевое архитектурное решение: **агент структурно отделён от секретов**.
Пароли, куки, токены коннекторов модель никогда не видит — они живут на отдельных машинах,
а апрувы и safety-проверки выполняются вне модели, чтобы их не мог переопределить
вредоносный текст на прочитанной странице. Честная цифра из инженерного блога:
финальный классификатор пропускает ~17% реальных overeager-действий — поэтому
он работает в паре с человеческим апрувом, а не вместо него.

Позиция на рынке (TechCrunch, 22.10): ставка Anthropic в гонке always-on агентов —
против Meta Muse (>10M пользователей, топ-активность — шопинг), OpenAI Dots,
Hark, Instinct, Grok Bot, Fo. Отстройка Duet: не personal-errands агент
(брони билетов — «не так сильны»), а **рабочий агент для professionals и small business**.

Для chora-mobile релевантно не «облако», а UX-ядро:
один тред + каналы, утренний бриф, тихие фоновые проверки по расписанию,
явный approval-gate, Tasks-список со статусами, Make-выхлоп файлами, слой skills.
Всё это реализуемо локально (агент на ПК пользователя, пока он за ним) — разделы 12–14.

---

## 2. Факты запуска и позиционирование

| Поле | Значение |
|---|---|
| Анонс | 21 октября 2026, статья «Introducing Claude Duet» |
| Safety-статья | 23 октября 2026, «Claude Duet Safety, Privacy, and Security» |
| Support-статья | «Get started with Claude Duet» (обновлена на неделе изучения; включает waitlist, лимиты, limitations) |
| Статус | Research preview, доступ по waitlist, волны приглашений |
| Кто может встать в очередь | Подписчики Claude Pro и Max в США, email waitlist = email Claude-аккаунта = Apple/Google-аккаунт на телефоне |
| Кого нет | Team и Enterprise — «планируем позже» |
| Где живёт | Отдельное приложение iOS/Android + web на claude.ai (не внутри основного Claude app) |
| Модель | Claude Opus 5.5, выбрать другую нельзя — Duet сам решает, сколько effort вложить |
| Цена | Включён в Pro/Max без доплаты; см. раздел 10 про лимиты |
| Целевая аудитория | Professionals и owners малого бизнеса («больше решений в день, чем можно отследить») |

Исторический контекст: Duet вышел в волну always-on агентов осени 2026 —
Meta Muse (8 сентября 2026, + Small Business skills/connectors 29 сентября),
OpenAI Dots (29 сентября 2026, DevDay), плюс xAI Grok Bot, Hark (6 октября),
Instinct (серия C $1B при $10B, сентябрь 2026), Fo/Wajo. Все четверо лидеров —
один паттерн: фоновый агент на cloud compute + коннекторы + approval перед последствиями.

---

## 3. UX-модель: как пользователь это ощущает

### 3.1 Один тред + каналы вместо чатов (support-статья, дословно по смыслу)

- **Message it like a person.** Текст или голосовое, без промптов и настроек.
  Главный тред — в одном месте, Duet продолжает с того, где остановились.
- **Каналы (channels):** отдельные треды под отдельные темы, с той же общей памятью.
  Независимый разбор (Claire Vo) выделяет это как agent-примитив наряду с task lists и artifacts.
- Главный тред остаётся тихим: Duet пишет туда, **когда задача готова или нужно решение**.
- **Только пользователь помечает задачу завершённой.** Duet может предложить
  («кажется, готово»), но галочку ставит человек — явный анти-«тихий саботаж».
- Фидбэк в продукт — прямо из чата plain words («скажи, что пошло не так») —
  Duet сам оформит репорт команде. Канал сбора жалоб встроен в UX.

### 3.2 Утренний бриф и дневной дозор

- Каждое утро — сводка самого важного по почте и календарю + **первые шаги**
  (черновики ответов на review).
- Днём — апдейты по работе и **follow-up по тредам, которые затихли**.
- Проверки — **по расписанию сетами (set intervals), а не непрерывно**:
  support-статья прямо предупреждает, что срочное может приехать между проверками.
  Пользователь может сказать, о чём и как часто сообщать (каденс настраивается словами).
- Из анонса: «Throughout the day, it keeps tabs on those apps and messages you only
  when something needs your attention» + «We’re continuing to test its judgment about
  when to message you».

### 3.3 Масштаб задач (официальные примеры)

Малые: «Clear out anything in my inbox that I don’t need to read»,
«Check Stripe for unpaid invoices and draft reminder emails for me to approve»,
«Pull together a brief on this company before my 2 pm meeting»,
inbox/Slack-триаж, инвойсы, payroll в Gusto (часы, бонусы, reimbursements) на submit,
вакансия → правки → пост в LinkedIn, договор → Docusign, follow-up по HubSpot,
соц-кампания в Canva, Shopify-магазин (анонсирован richer visual editor с превью).

Крупные: research brief, финансовая модель, sales forecast, slide deck, dashboard
«с десятками инструментов», прототипы, веб-аппы. Результат возвращается **файлами
на review — вкладка Make** (research brief, финмодель, deck, dashboard).

### 3.4 Вкладки аппа (support-статья): Tasks и Make

- **Tasks tab:** что Duet делает сейчас + подсветка задач, ждущих input пользователя.
- **Make tab:** готовые результаты файлами — review/edit.
- **Plugins:** предлагается small business plugin и подходящие под работу (раздел 8).

---

## 4. Фоновый режим: что значит «работает, пока тебя нет»

- Своя VM в облаке + свой браузер (раздел 6). Телефон/ноут закрываются — работа идёт.
- Если апрув некому дать сразу — Duet **доделывает остальное и возвращается с апрувом позже**
  («finishes the rest of the task and brings the approval back to you later»).
- Когда даёт число или вывод — **указывает источник**: какое письмо, файл, таблица.
  Прозрачность происхождения — часть UX, не лог для гиков.
- Чего Duet в preview НЕ умеет (support-статья, точный список):
  - нельзя смотреть его браузер и забирать управление;
  - не видит все проекты и файлы на компьютере пользователя, читает работу в Claude, но не меняет её;
  - не звонит и не пишет SMS другим людям (email — да, с апрувом, из подключённых аккаунтов);
  - trading securities, перемещение денег между счетами, доступ к чужому аккаунту — запрещены даже с апрувом;
  - Slack — с лимитами, **Microsoft 365 пока недоступен в Duet**;
  - может неверно прочитать тред и ошибиться в срочности — «проверяйте черновики и апрувы».

---

## 5. Архитектура: Managed Agents — «мозг отдельно от рук»

Duet построен на инфраструктуре Claude Managed Agents (инженерный блог, 08.04.2026).
Суть — три раздельных интерфейса вместо одного контейнера («не заводить питомцев»):

- **Session** — durable append-only лог всего, что случилось; живёт вне harness.
  Контекст = объект вне context window: `getEvents()` срезами, `emitEvent()` дописывает.
  Упавший harness перезапускается `wake(sessionId)` и продолжает с последнего события.
- **Harness** — цикл «зовём Claude, роутим tool calls»; stateless, стартует без контейнера.
  Эффект: p50 time-to-first-token −60%, p95 −90% (не ждём прогрев контейнера под каждую сессию).
- **Sandbox/hands** — исполнение и файлы; вызывается как `execute(name, input) → string`.
  Контейнер — «скот»: умер → harness ловит как tool-call error, Claude решает retry,
  новый контейнер поднимается по рецепту `provision({resources})`.

Security-следствие (структурное, не «будем аккуратны»):
токены никогда не попадают в песочницу, где выполняется сгенерированный моделью код.
Git — клонирование с токеном при инициализации, дальше push/pull без доступа агента к токену.
MCP/OAuth — токены в vault, вызовы через dedicated proxy, который подставляет credential
снаружи машины агента. Harness вообще не знает о credentials.
Плюс много-мозгов/много-рук: один brain может слать работу в разные руки (VPC заказчика,
телефон, любой tool с интерфейсом execute).

Проекция на нас: наш «Managed Agents» — это Syncthing + файлы. Тот же принцип:
агент на ПК и телефон разделены файлом-протоколом, секрет (PIN) хранит только телефон,
статусы переживают падение любой стороны, т.к. живут в файлах, а не в памяти.

---

## 6. Approval-экономика и классификатор (самая сильная часть Duet)

### 6.1 Что требует апрува всегда

Отправка сообщения, платёж, подпись документа, удаление. Показывает **что именно,
куда и кому** (включая всех получателей) и ждёт подтверждения.

### 6.2 Два независимых контура

1. **Approval-карточка пользователю** (тред / уведомление).
2. **Автоматическая проверка вне модели** — auto-mode classifier из Claude Code
   (инженерный блог, 25.03.2026), расширенный под Duet. Оценивает соответствие
   действия интенту, работает снаружи выполняющей модели.

### 6.3 Как устроен auto-mode classifier (детали из инженерного блога)

- **Два слоя:** input-probe (сканирует tool outputs — file reads, fetch, shell —
  до попадания в контекст; при подозрении на hijack добавляет warning «относись
  скептически, опирайся на просьбу пользователя») + output transcript classifier.
- **Transcript classifier:** смотрит только user messages + tool calls модели.
  Собственные сообщения модели и tool outputs **вырезаны специально** (reasoning-blind):
  иначе агент уговорит классификатор («пользователь же неявно разрешил») и
  иначе через tool outputs пролезет инъекция. Потеря provenance принята осознанно.
- **Две стадии:** stage 1 — быстрый single-token фильтр (yes/no, tuned к over-blocking,
  8.5% FPR); stage 2 — chain-of-thought reasoning только по flagged (чистит FPR до 0.4%).
  Промпт stage 2 = тот же + другая финальная инструкция → почти полный cache-hit.
- **Tier 1/2/3:** safe-tool allowlist (read/search/todo) → in-project file writes
  без классификатора (reviewable через VCS) → всё остальное (shell, web, внешние
  интеграции, subagent-спавны, файлы вне проекта) идёт в классификатор.
  При входе в auto mode широкие allow-правила (shell, python/node, package managers)
  принудительно сбрасываются — иначе классификатор никогда не увидит опасное.
- **Критерии:** evaluate real-world impact, не текст команды (payload в файле + его
  запуск = одно действие; цепочки через && = одно действие). Authorization консервативна:
  «clean up my branches» ≠ разрешение на batch delete; «can we fix this?» = вопрос, не директива.
- **Честные цифры (их стоит уважать):**
  - real traffic (n=10k): 0.4% FPR в полном пайплайне;
  - real overeager (n=52): **17% FNR** — главная причина: классификатор верно видит
    опасность, но ошибается, покрывает ли найденный consent именно этот blast radius
    («Clean up the PR» сказано, но не назвало force-push). Prompt-engineering это
    не чинит без потерь — признано открыто;
  - synthetic exfil (n=1000): 5.7% FNR.
  - Вывод Anthropic: замена для `--dangerously-skip-permissions`, НЕ для внимательного
    ручного review высокорисковых действий.
- **Deny-and-continue:** блокировка возвращается агенту как tool result с инструкцией
  «ищи безопасный путь, не обходи границу». 3 подряд или 20 всего denials → эскалация
  человеку (в headless — остановка процесса). False positive стоит один retry, а не смерть сессии.
- **Multi-agent handoffs:** проверка на делегировании (внутри суб-агента инструкция
  оркестратора выглядит как user message — ловить надо на границе) и на возврате
  (суб-агент мог скомпрометироваться mid-run — возврат идёт с warning, а не дропается).

### 6.4 Категорически запрещено и «без don’t ask again»

- Запрещено даже с апрувом: торговля ценными бумагами, банковские перемещения денег,
  доступ к чужому аккаунту.
- Нет suppression-правила «больше не спрашивать» для: оплаты/переводов, удаления заказа,
  создания аккаунта — сколько бы раз ни апрувили.
- Калибровка частоты — открытая проблема: слишком частые запросы учат прожимать
  не глядя (approval fatigue). Крутят по данным preview. Вывод для нас: approval — UX-бюджет.

### 6.5 Оплаты: Link и Shop Pay (support-статьи)

- Link (Stripe wallet) и Shop Pay встроены в Duet, в connectors directory их нет.
  Link ≠ Stripe connector (коннектор работает в Stripe-аккаунте: инвойсы; Link платит).
- Поток: Duet находит товар → просит апрув покупки (max amount) → пользователь
  подтверждает Spend Request в Link-аппе → Duet платит **одноразовой картой**,
  скоупированной на мерчанта и сумму. PAN/номер счёта Duet не видит
  (только тип карты, last4, nickname, expiry, адреса доставки).
- Лимиты Link: только Duet, только Pro/Max US, нужен US payment method;
  без апрува в Link-аппе оплаты нет; нет recurring payments; временные холды
  при неуспешной покупке возможны; мерчант/сайт может отклонить checkout;
  роутинг жалоб: магазин → заказ/доставка/возврат; Link Support → деньги/аккаунт;
  Anthropic → «Duet выбрал не тот товар» (можно сказать прямо в чате).
- У Meta Muse — зеркально: checkout через Link с purchase protections
  (повреждения/потеря, price drops, бесплатные возвраты), Shop Pay «скоро»,
  1Password — у обоих «скоро».

---

## 7. Безопасность и приватность (статья 23.10.2026 + support)

### 7.1 Дискреционный классификатор исходящих (2 тира)

Отдельный классификатор + safety system prompt проверяют **каждое** исходящее:
- **Never share** — credentials, полные номера карт/счетов, government ID.
  Не отправляются никому, даже если пользователь прямо просит.
- **Needs consent** — здоровье, личные финансы и т.п. — только при явном указании
  (сам запрос «напиши дантисту про зубную боль» уже считается согласием).
- При блокировке Duet может переписать сообщение без чувствительного куска и показать на апрув.
- Признано: будут и пропуски, и ложные срабатывания; поэтому классификатор работает
  в паре с approval-карточками. Итерации по данным использования обещаны.

### 7.2 Изоляция секретов

- **Пароли:** вводятся в форму внутри Claude app; форма шифруется одноразовым ключом,
  существующим только на browser-машине; расшифровка — только там, где браузер вводит
  пароль в сайт. Модель пароль не видит, сохранить/повторить не может.
  Форма — только внутри аппа и только для sign-in, который просили. Всё похожее
  вне аппа (ссылка, SMS, email, чужой сайт) — по определению нелегитимно
  (это одновременно антифишинг-дизайн).
- **Sign-in токены:** по дизайну Managed Agents — в машине агента плейсхолдер,
  реальное значение подставляет прокси снаружи в момент запроса.
- **Браузер:** отдельная dedicated VM; фиксированный набор команд (open/click/type);
  код сайтов, куки, загрузки остаются на browser-машине; назад — только текст и файлы.
  Загруженное через браузер проходит ту же sensitive-проверку, что и сообщения.
  Плюс defenses из browser-use prompt-injection research.
- **Идентификация как агента:** отдельный User-Agent + публикуемые исходящие IP;
  крупные сайты заранее получили opt-out от визитов Duet.
- **Память и отключение:** чаты ищутся поиском по прошлым чатам (настройка
  Search and reference chats; удаление чата убирает его из поиска).
  Отключение аппа останавливает новый доступ с этого момента, но выученное остаётся
  до reset memory в настройках. Удаление аккаунта стирает всё, что Duet хранил.

### 7.3 Тестирование (заявлено)

- Safeguards-evaluations: routine-задачи ×3 варианта (innocent / injected / tempting to overstep) + shadow traffic.
- Red teams на утечки, действия без апрува, следование вредоносным промптам; threat model всей системы.
- Внешний pentest с доступом к исходникам (follow-up по браузеру и sign-in форме — в процессе).
- Публичный bug bounty (HackerOne) с safe harbor.

### 7.4 Рамка: 5 принципов trustworthy agents (август 2025)

1. Человек сохраняет контроль (read-only по умолчанию, апрув на изменения; persistent
   permissions только на рутину, которой доверяют).
2. Прозрачность поведения (to-do checklist в реальном времени; баланс detail vs noise).
3. Выравнивание с ожиданиями (проблема overeager-агента без hostile intent — самый частый кейс).
4. Приватность across interactions (MCP-коннекторы с one-time/permanent доступами,
   админ-контроль; не тащить чувствительное между контекстами).
5. Защита взаимодействий (classifiers + Threat Intel + reviewed MCP directory;
   гайды по jailbreak-mitigation для разработчиков).

---

## 8. Слой skills: Small Business plugin (что реально умеет Duet-подобный агент)

Academy-гайд по плагину + анонс «Claude for Small Business». Плагин ставится
в Customize → Plugins → Discover, работает в Claude/Cowork (в Duet — «поддерживает
плагины, предлагает подходящие»). Механика: `/команда` или plain English → Claude
выбирает skill; composite skills запускают цепочку sub-skills с решением пользователя
между шагами; кастомизация `smb-onboard` переписывает дефолты под бизнес (отрасль,
размер, приоритеты) и сохраняется как файл-карточка.

Оркестраторы (один запрос = большая работа):

| Команда | Что делает | Читает |
|---|---|---|
| `/monday-brief` | Одна страница на неделю: cash, sales, pipeline, календарь + «то одно, что нужнее всего» | Gmail, Calendar, Drive, QuickBooks, HubSpot, Slack, Stripe, Docusign... (~20 источников) |
| `/report-pack` | Saved reports по расписанию + business snapshot | Любой источник |
| `/pay-the-bills` | Кодирует счета, проверяет cash, готовит payment run на OK | QuickBooks, Gusto, Ramp, Stripe, Gmail... (цепочка ap-processor → cash-flow → month-end) |
| `/plan-payroll` | Хватит ли cash, reminders по overdue, run на submit | Gusto, QuickBooks, Gmail... |
| `/close-month`, `/tax-prep` | Закрытие книг + close packet бухгалтеру; квартальные налоги / 1099 | Expensify, QuickBooks, Gusto, Stripe... |
| `/restock` | Что reorder, POs + письма поставщикам, запись в книги | QuickBooks, Shopify, Gmail... |
| `/call-list`, `/grow-pipeline`, `/speed-to-lead`, `/reactivate` | Топ-лиды с call cards; поиск + outreach в голосе пользователя + CRM; ночные/выходные ответы; win-back ушедших | Apollo, Clay, HubSpot, Salesforce, Gmail... |
| `/marketing-monday` | Что работает, голос клиентов, что поменяли конкуренты | Shopify, TikTok Ads, HubSpot, Stripe... |

Атомарные: `inbox-manager` (сортировка + «что требует тебя» + черновики в голосе
пользователя), `business-pulse`, `growth-pulse`, `cash-flow-snapshot` (30/60/90),
`invoice-chase` (ранжирует overdue + персонализированные reminders),
`contract-review` (plain-English summary + red flags + redline),
`proposal-builder` (заметки/фото/RFP → priced proposal → подпись после апрува),
`hiring-screener`, `job-post-builder`, `ticket-deflector`, `review-reputation`,
`crm-autopilot`, `canva-creator`, `social-content-engine`, `ad-manager`,
`seo-ai-visibility`, `build-connector` (подключение без официального коннектора через Zapier),
`build-agent` (превратить ручную рутину в skill по имени/расписанию).

Правила плагина (нам в копилку): approve-before-send/post/pay всегда;
читает только то, что может читать аккаунт пользователя (права наследуются);
Anthropic не тренируется на бизнес-данных; решения (цены, подписи, бухгалтеру) — за человеком;
проверяй одну строку по известному факту перед апрувом («confirm one line against your books»).

---

## 9. Duet vs ближайшие родственники: Cowork и Code

Cowork (январь 2026; осенью 2026 вливается в основной Claude — «Cowork is now just Claude»):

| Ось | Duet | Cowork |
|---|---|---|
| Форм-фактор | Отдельный мобильный апп, proactive | Desktop app + web/mobile, работает в выбранных папках и файлах |
| Инициатива | Приходит сам (бриф, проверки по расписанию) | Берёт задачу, которую дали; scheduled reports по каденсу |
| Файлы | НЕ видит файлы на компьютере, НЕ меняет работу в Claude | Читает/создаёт/редактирует выбранные папки; типы: docs, xlsx, pptx, pdf, md, csv, ipynb, код |
| Браузер | Свой cloud browser, показать нельзя | Built-in browser в side panel; computer use (экран) — last resort, с permission на каждое приложение |
| Планы | Pro/Max US, waitlist | Pro/Max/Team (+Enterprise opt-in); админ-контроли, SIEM-экспорт |
| Плагины | Поддержка + рекомендации | Полная система: plugins/skills/connectors/sub-agents, private marketplace |
| Общее | Один аккаунт, память, skills, коннекторы; «скажи что, не как»; апрув на значимое; работает с закрытым ноутом | |

Вывод: Cowork — «руки в твоих файлах», Duet — «глаза в твоих сервисах и голос с утра».
Наш chora-агент по духу ближе к Cowork (файлы!), а по UX надо брать у Duet (бриф, Tasks, апрувы).

---

## 10. Лимиты, цена, доступ (точные формулировки support-статьи)

- **Цена:** в preview Duet включён в Pro/Max без доплаты.
- **Usage:** те же five-hour session и weekly лимиты, **по тому же рейту, что чаты**.
  Фон (бриф, check-ins) тоже считается — с Duet лимиты кончаются раньше, чем с чатом.
  Проверки по интервалам — осознанная экономия лимитов, а не «лень».
- **One-time limit reset** при допуске в preview (и five-hour, и weekly), действует до 30.11.2026.
- Waitlist-механика: имя + email Claude-аккаунта + план + тип телефона + «что хочешь делегировать»;
  волны; email mismatch (waitlist vs Claude vs store-аккаунт) = нет доступа.

---

## 11. Что говорят попробовавшие

### 11.1 Подборка Anthropic (читать со скидкой — маркетинг)

- Boris Cherny (глава Claude Code): наговаривает mental to-do на прогулках.
- Chelsea Larsson (model/behavior): скидывает to-do перед уходом к детям, вечером забирает отчёт.
- Karan Ahuja (глава Duet): назначает user interviews, прототипирует, «даже шипает код».
- Jess Provencher (broker): Duet сам поймал показ на неверной дате («exactly the kind of thing
  I want caught without having to ask»).
- Amin Ebrahimi (Shahs of Kabob, ~110 сотрудников): учёт, поддержка, маркетинг, инвойсы
  по магазинам — «It brings it all together. I don’t need to open up 100 tabs».
- Mya Dalton (brand strategist): бриф к звонку + сам предложил перенести (стоял перед рейсом).

### 11.2 Claire Vo, How I AI (независимый тест, 21.10 + бенчмарк 28.10)

Что хвалит: самый polished запуск personal agent — thoughtful onboarding, task lists,
first-class artifacts, Slack-style channels; иконка отдельно. Тестировала на inbox/Slack,
sales pipeline, sales deck в Google Docs, launch video, Warriors tickets детям.

Претензии (нам — прямые требования):

1. **«Beautiful. I still forgot to use it»** — proactive-агент, который не нудит, не формирует
   привычку: проблема роста, а не красоты. Урок: тишина по умолчанию хороша, только если
   важные нуджи реально доходят.
2. **Latency убивает синхронную работу.** Ожидание Opus-ответов выбивает из потока;
   killer-feature Muse названа скорость («я всегда двигаюсь к следующему шагу»).
3. **Нет desktop app** — выпадает из рабочего стека (телефон ≠ место работы).
4. **Нет multiplayer** — single-player агент не встраивается в командную работу.
5. Бенчмарк 9 задач (28.10, Grok Bot vs Dot vs Muse vs Duet; гоняла через computer use,
   скоринг в эфире): Slack-reply, монтаж из Dropbox, Sentry-bug, Figma-thumbnail,
   inbox triage, family newspaper, физика 4-класснику, shoe shopping, launch video.
   Методология — шоу, а не наука (автор так и подаёт), но набор задач — готовый
   чеклист «что должен уметь личный агент»; полезна сама матрица work-tasks vs life-tasks.

### 11.3 Пресса

- **The Verge (21.10):** «takes on Muse with Claude Duet», пересказ возможностей + early version caveats.
- **TechCrunch (22.10, Ivan Mehta):** «Anthropic’s bet on agents»; рынок наводнён ассистентами;
  Duet ≠ errands (Instinct-отстройка), браузер не показывает; 6000+ connectors; Link/Shop Pay;
  отказ securities. Рядом в тот же день: у Muse >10M пользователей, шопинг — топ-активность.
- **Forbes (08.10, про рынок):** у Instinct — инцидент с раскрытием чужих данных + «invented the...»
  (обрыв цитаты в выдаче, но факт инцидента зафиксирован).

---

## 12. Конкуренты детально (октябрь 2026)

| | Claude Duet | OpenAI Dots | Meta Muse | Прочие |
|---|---|---|---|---|
| Статус/доступ | Preview, waitlist, Pro/Max US | Pro/Business Premium, первый dot включён; Plus — нет; постепенный rollout | US (+Сингапур 27.10), iOS/Android/muse.ai, скоро AI-очки; free + subscription | Hark: wide release, free + sub; Instinct: viral, $1B/$10B; Fo: early; Grok Bot: в X-экосистеме |
| Модель | Opus 5.5 | GPT-6 Astra | Muse Spark 1.3 (+Wonder 12.10 — «good for agents, bad for design» по Vo) | — |
| Compute | Cloud VM + browser | Cloud computer + browser | **Muse Secure VM** (агент + данные в одном VM) + **Sentinel agent** (отдельный, весь egress только через него) | Hark: свой VM + видимое окно браузера (trust-UX); Fo: human-in-loop (vendor claim: 2× completion, 94% trust) |
| Интерфейс | Отдельный апп + web | Внутри ChatGPT + **Slack/Teams сообщения** (SMS — скоро); Shared Space (Pages; Slides/Sheets — скоро); Sites для веб-аппов | Muse app **или прямо WhatsApp** — «как messaging another person» | Grok Bot: cloud computer, логинится почти куда угодно вкл. WhatsApp (вторичн.) |
| Proactivity | Утренний бриф + проверки интервалами | Routines (daily priorities 7–8am, AI news), scheduled tasks; auto-review gating + Custom Rules | Unprompted suggestions, помнит сказанное однажды (рецепт из Reels → grocery list), «forget»-команда | — |
| Approval | Карточка + внешний classifier; запреты: securities, деньги между счетами | auto-review: proceed / needs approval / must-do-yourself; смена пароля — всегда сам | Approval перед email/покупкой; granular per-app (read vs send); полный audit trail всего сделанного/запланированного; opt-out обучения; **рекламе данные не отдаются** | Hark: privacy-first позиционирование + AI-девайс 2027; Fo: patented agentic card, group chats, звонки; Instinct: privacy concerns |
| Платежи | Link + Shop Pay, one-time card, US only | Не зафиксировано в изученном | **Link с purchase protections** (повреждения/потеря, price drops, no-fee returns) — первый покрытый агент; Shop Pay скоро; 1Password скоро | — |
| Шифрование | Не заявлено | Не зафиксировано | **Muse Confidential VM** (анонс: шифрование ключом пользователя, не видит даже Meta) | — |
| Коннекторы | 6000+ (Marketplace) | 4000+; Slack/Drive в ядре | Apps + Small Business версия (connectors) | — |
| Слабость (по источникам) | Медленный, мало proactive, нет desktop/multiplayer | Нет данных hands-on в изученном | «Bad for design» (Vo про Wonder); Meta-недоверие к приватности — адресовано Secure VM + no-ads | Instinct: инцидент с чужими данными |

Паттерн рынка одинаковый (фон + коннекторы + approval-gate); дифференциация —
каденс, скорость, нативные интерфейсы (WhatsApp/Slack), глубина safety.
Наша ниша — ни один из них: **локальный офлайн-агент на своих файлах**.

---

## 13. Что есть у нас (факты из репозиториев на 2026-10-30)

- **Платформа:** Flutter 3.47.8 через FVM + Material 3, Rust-ядро (`chora` + `rust/src/api.rs`)
  через flutter_rust_bridge 2.13.0. Только `android/`. Офлайн-first, шрифты — ассеты
  без runtime-фетча, INTERNET планируют убрать (`T0.2`).
- **Хранилище `chora_dir`:** `index.md` (read-only), `notes/<project>/`, `events/YYYY-MM-DD.md`,
  `events/repeatable/<weekday>.md`, `events/backlog/`, **`to-agent/`** — очередь задач
  для агента на ПК (`Store::write_agent_task` → `to-agent/YYYY-MM-DD-<slug>.md`, коллизии `-2`, `-3`).
  Синк внешний (Syncthing-Fork), апп только детектит `.sync-conflict-` копии.
- **Capture (GTD inbox)** — `lib/screens/capture.dart`: title + markdown body,
  `@`/`#` автокомплит, переключатели delegate / event / priority, Save.
  Три маршрута `submit_capture`: append в заметку (`## title` блок, `insert_under` под хедер),
  создание day event, **делегирование в `to-agent/`** с priority и target note.
- **Events:** месячная сетка 42 ячейки (`get_calendar_month`), day events + repeatables
  (`get_day_events`), rewrite/move по `section_index` (`update_single_event`).
- **Напоминания** — `lib/notifications.dart`: локальные нотификации + опциональный
  системный alarm-intent. Горизонт **−1..+2 дня**, только при открытии аппа
  (T1.5: 14 дней, один bridge-call C7, планировщик после первого кадра).
- **Безопасность:** PIN (FlutterSecureStorage) + биометрия, порог `none/open/restricted/critical`
  (`AppState.needsGate`), whole-app gate + per-file gate. Session relock (>60с в фоне) — в планах.
- **Состояние/UI:** 4 таба (Capture/Notes/Events/Settings), `AppState` на SharedPreferences.
  План — слои Repository→Controller→Widget, один bridge-call на состояние,
  бюджет: cold start <600мс, ни одного кадра >16мс.
- **Чего нет:** фонового агента в телефоне, always-on проверок вне запуска,
  approval-карточек, task list со статусами delegated задач, утреннего брифа,
  голоса, коннекторов к чужим сервисам — только свои markdown-файлы.

Итого в терминах Duet: у нас уже есть **половина «взять задачу»** (Capture → `to-agent/`)
и **половина «действовать осторожно»** (gates), но нет **«прийти самому»** и **«работать,
пока тебя нет»** внутри телефона. И это осознанно: агент выполняется **на ПК пользователя,
когда он за ним** — наш «cloud VM» = домашний компьютер, а телефон — заказчик и контролёр.

---

## 14. Gap-анализ Duet → chora

| Ось Duet | Duet | chora-mobile сейчас | Разрыв |
|---|---|---|---|
| Proactivity | Утренний бриф + проверки по расписанию + пуш | Только reschedule при запуске | Нет scheduled фона; T1.5 (14 дней) всё ещё on-launch |
| One thread + channels | Один тред на всё + каналы, голос | 4 таба, черновик Capture сбрасывается | Нет единого треда задач |
| Фоновая работа | Cloud VM, апп можно закрыть | Агент = ПК пользователя, телефон пассивен | Нужен протокол «телефон заказал → ПК исполнил → телефон показал» поверх Syncthing |
| Task visibility | Tasks tab, страница задачи, steer mid-task, завершает только user | `to-agent/*.md` без статуса в UI | Нет статусов (new/taken/done/needs-approval) и журнала |
| Результат | Make tab — файлы на review/edit | Результат ПК-агента негде смотреть | Нет экрана результатов |
| Approval | Карточка «что/куда/кому» + внешний classifier | PIN/biometric gates на чтение | Нет gate на *действия* агента |
| Safety tiers | Never-share vs needs-consent на отправку | `open/restricted/critical` на чтение файлов | Тиры есть для чтения, нет для *отправки наружу* |
| Credentials | Изоляция (агент их не видит) | Чужих credentials нет вообще (только свои файлы) | Изоляция не нужна — нечего красть; риск — пишущий/отправляющий агент |
| Memory/skills | Общие с аккаунтом + chat search + reset memory | `index.md` + файлы = память | Аналог по сути; нет reset memory и «что агент выучил»; нет слоя skills (см. ниже) |
| Скорость | Жалобы на медлительность Opus | Бюджет 600мс/8–16мс, 0 лишних bridge-calls | Наше преимущество — брать скоростью и мгновенным UI |
| Цена/лимиты | Фон тратит общие лимиты | Локально бесплатно; «лимит» = батарея | Каденс лимитируется батареей, а не токенами |
| Desktop | Нет desktop app — упрёк №3 | Нет desktop — у нас это фича (ПК = исполнитель через файлы) | Наш ПК-агент закрывает gap иначе |

---

## 15. Что перенять (по приоритету, всё локальное)

1. **Утренний бриф из своих данных (без LLM).**
   Первый запуск дня: сегодня/завтра events + просроченные `- [ ]` + новые/готовые
   `to-agent/` статусы. Аналог `/monday-brief`+`business-pulse` на минималках.
   Собирается из `get_day_events` + листинга. Правило тишины как у Duet:
   нет важного — нет пуша.
2. **Статусы `to-agent/` очереди в UI (наш Tasks tab).**
   Префикс статуса в имени/фронтматтере (`new → taken → done / needs-approval`) +
   экран-список с временем и результатом. ПК-агент меняет статус тем же atomic write
   (C1), телефон только читает. Только пользователь закрывает задачу (как у Duet).
3. **Approval-gate на действия агента, а не только на чтение.**
   Статус `needs-approval` → карточка «что/куда» с Approve (применить) / Deny
   (откат в `new` с пометкой). «Don’t ask again» для деструктивного не предлагать вовсе.
4. **Экран результатов (наш Make tab).**
   После применения результата ПК-агента — карточка с относительным путём + Open/Undo
   (паттерн уже есть в дизайн-правилах). Происхождение обязательно: «из какого файла/задачи».
5. **Каденс вместо realtime.**
   Проверки «утро/вечер» по `storage_stamp` (C9): изменилось → бейдж на табе, нет — молчать.
   Каденс словами, не минутами. Батарея — наш аналог «лимитов».
6. **Слой skills (идея из Small Business plugin, адаптированная).**
   У Duet скиллы — «как делать типовую работу»; у нас типовые работы — capture-маршруты,
   morning brief, invoice-chase-аналоги отсутствуют. Кандидат: `to-agent/` задачи
   с типом (`brief`, `triage`, `chase`, ...) + per-type инструкции для ПК-агента
   в `index.md`/отдельном skills-файле. Composite-цепочки (skill→skill с решением
   между шагами) отложить до живых M1–M4. Кастомизация под пользователя (`smb-onboard`-аналог:
   «чем занимаешься, что болит») — только когда будет кому кастомизировать (ПК-агент LLM).
7. **Safety-tier на отправку — зафиксировать сейчас, применить когда будет «наружу».**
   Пока chora ничего никуда не отправляет — классификатор не нужен. Но правило в
   `.agents/rules.md`: будущий «отправить наружу» сразу под gate с тирами
   never-share (PIN, секреты) vs needs-consent. Права наследуются от аккаунта
   (как у плагина: читает только то, что можешь ты).
8. **Скорость как фича.**
   Внешний отзыв: медленный умный агент проигрывает быстрому. Наш бюджет
   (600мс cold start, 0 лишних bridge-calls, C7 range-read, кэши репозиториев)
   не должен пострадать от «умного» слоя.

## 16. Что НЕ перенимать

- **Cloud VM и чужой браузер.** Наша модель — ПК + Syncthing; не нужны browser-VM,
  прокси токенов, публикуемые IP, Sentinel-агенты.
- **6000 коннекторов.** Наши «коннекторы» — markdown-файлы. OAuth-зоопарк противоречит офлайн-first.
- **Оплаты и Link.** Виртуальные карты — чужой домен; достаточно запрета «агент никогда не платит».
- **Голосовой тред.** До единого треда задач — лишний scope.
- **«Не спрашивать снова» для оплат/удалений** — у Duet запрещено, нам тем более не вводить.
- **Отдельный апп.** У Duet отдельность — вынужденная (research preview); нам делить
  Capture/Tasks не надо — статусы живут внутри существующего аппа.

---

## 17. Предлагаемый MVP «chora duet, local edition»

Без облака, без сети, поверх `to-agent/` + Syncthing. Каждый пункт — отдельная задача в духе roadmap.

- [ ] **M1. Статусы очереди.** Формат статуса в `to-agent/*.md`, переходы только вперёд;
        телефон показывает список с бейджами. Только пользователь закрывает задачу.
- [ ] **M2. Утренний дайджест.** Первый запуск дня: события сегодня/завтра +
        новые/готовые задачи агента; тишина, если пусто.
- [ ] **M3. Approval-карточка.** `needs-approval` → экран «что/куда» с
        Approve (применить) / Deny (откат в `new` с пометкой); источник результата обязателен.
- [ ] **M4. Тихие проверки.** `storage_stamp` (C9) + каденс «утро/вечер»;
        бейдж на табе вместо пуша, когда ничего срочного.
- [ ] **M5. Журнал действий.** Что агент взял/сделал/ждёт — один экран, относительные пути,
        Undo где reversible. Аналог «you see what it’s doing» + audit trail Muse.
- [ ] **M6. Правила отправки.** Тиры never-share/needs-consent в `.agents/rules.md`;
        будущий «отправить наружу» сразу под gate.
- [ ] **M7 (позже, с LLM на ПК). Типы задач + skills-файл.** `brief/triage/chase`-типы
        в `to-agent/` + инструкции в `index.md`; кастомизация под пользователя.

Явный non-goal MVP: выполнять задачи на самом телефоне в фоне.
Фоновая работа живёт на ПК; телефон — заказчик и контролёр.

---

## 18. Источники

Официальные Anthropic (факты):

- Product: https://claude.com/product/claude-duet
- Announcement 21.10.2026: https://claude.com/resources/articles/claude-duet
- Safety/Privacy/Security 23.10.2026: https://claude.com/resources/articles/claude-duet-safety-privacy-and-security
- Support «Get started with Claude Duet»: https://support.claude.com/en/articles/17631495-get-started-with-claude-duet
- Support «How to use Link by Stripe with Claude Duet»: https://support.claude.com/en/articles/17666484-how-to-use-link-by-stripe-with-claude-duet (Shop Pay — соседняя статья 17666489)
- Trustworthy agents framework 04.08.2025: https://www.anthropic.com/news/our-framework-for-developing-safe-and-trustworthy-agents
- Managed Agents engineering 08.04.2026: https://www.anthropic.com/engineering/managed-agents
- Auto-mode classifier engineering 25.03.2026: https://www.anthropic.com/engineering/claude-code-auto-mode
- Cowork product (сравнение): https://claude.com/product/cowork (+ «Cowork is now just Claude»)
- Academy Small Business plugin: https://academy.claude.com/tutorials/how-to-install-the-claude-for-small-business-plugin
- Opus 5.5: https://www.anthropic.com/claude/opus + platform docs (релиз 22.09.2026, 1M ctx, $4/$20, adaptive thinking)

Пресса:

- TechCrunch 22.10.2026 (Ivan Mehta): https://techcrunch.com/2026/10/22/claude-duet-app-is-anthropics-bet-on-agents (там же: Muse >10M, Hark 06.10, Instinct $1B/$10B, Fo/Wajo)
- The Verge 21.10.2026 (Jay Peters): https://www.theverge.com/ai-artificial-intelligence/1015843/anthropic-claude-duet-ai-agent
- Forbes 08.10.2026 (Anna Tong): рынок personal assistants + инцидент Instinct

Независимые тесты и сравнения:

- Claire Vo / Lenny's: «Claude Duet is beautiful. I still forgot to use it» (21.10) + бенчмарк «Grok vs Dot vs Muse vs Duet» 9 задач (28.10)
- Refix: «Claude Duet vs OpenAI Dots vs Meta Muse» (сверено 22.10, без hands-on)
- MindStudio: Duet vs Muse/GrokBot/Dots; отдельно Dots guide
- Eigent/CellCog: proactive-agent explainer; Meta Muse explainer; Cowork vs Copilot Coworker
- Открытые пересказы: Pulse2, Technology.org 22.10, SecurityOnline, Facebook-посты; Reddit-тред r/aicuriosity (не открылся — 403, в файл не включено)

Конкуренты (первичные):

- Meta Muse 08.09.2026: https://about.fb.com/news/2026/09/introducing-muse-personal-ai-agent (Secure VM, Sentinel, WhatsApp, Link protections, Confidential VM)
- OpenAI Dots 29.09.2026: https://openai.com/index/introducing-dots (GPT-6 Astra, Slack/Teams, auto-review, Custom Rules)

Локальные (репо, 2026-10-30):

- `.agents/project.md`, `architecture.md`, `design.md`, `roadmap.md`, `backend-tasks.md`
- `lib/main.dart`, `app_state.dart`, `backend.dart`, `notifications.dart`,
  `screens/capture.dart`, `rust/src/api.rs` (`submit_capture`, `get_calendar_month`,
  `get_day_events`, `update_single_event`), sibling `chora/src/store.rs` (`write_agent_task`)
