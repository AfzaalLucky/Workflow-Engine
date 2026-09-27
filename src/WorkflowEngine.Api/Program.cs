using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using WorkflowEngine.Api.Events;
using WorkflowEngine.Api.Samples.LeasingCommissions;
using WorkflowEngine.Api.Samples.PurchaseRequests;
using WorkflowEngine.Api.Security;
using WorkflowEngine.Application;
using WorkflowEngine.Application.Abstractions;
using WorkflowEngine.Application.Events;
using WorkflowEngine.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "Paste the token returned by POST /api/auth/login."
    });
    options.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference { Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme, Id = "Bearer" }
            },
            []
        }
    });
});

builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUserContext, JwtCurrentUserContext>();

builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection("Jwt"));
builder.Services.AddSingleton<JwtTokenService>();

var jwtOptions = builder.Configuration.GetSection("Jwt").Get<JwtOptions>()
    ?? throw new InvalidOperationException("Missing Jwt configuration section.");

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtOptions.Issuer,
            ValidateAudience = true,
            ValidAudience = jwtOptions.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.SigningKey)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });
builder.Services.AddAuthorization();

builder.Services.AddWorkflowInfrastructure(builder.Configuration);
builder.Services.AddWorkflowApplication();
builder.Services.AddScoped<IPurchaseRequestRepository, PurchaseRequestRepository>();
builder.Services.AddScoped<ILeasingCommissionRepository, LeasingCommissionRepository>();

// Lifecycle events: outbox dispatcher + delivery targets. Host applications
// add their own reactions with AddWorkflowEventHandler<T>().
builder.Services.Configure<WorkflowEventOptions>(builder.Configuration.GetSection("WorkflowEvents"));
builder.Services.AddHttpClient(WebhookWorkflowEventHandler.HttpClientName, client => client.Timeout = TimeSpan.FromSeconds(15));
builder.Services.AddWorkflowEventHandler<WebhookWorkflowEventHandler>();
builder.Services.AddWorkflowEventHandler<LeasingCommissionStatusSyncHandler>();
builder.Services.AddHostedService<WorkflowEventDispatcher>();

var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? ["http://localhost:5183"];
builder.Services.AddCors(options =>
{
    options.AddPolicy("WorkflowEngineClient", policy =>
        policy.WithOrigins(allowedOrigins)
              .AllowAnyHeader()
              .AllowAnyMethod());
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("WorkflowEngineClient");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
