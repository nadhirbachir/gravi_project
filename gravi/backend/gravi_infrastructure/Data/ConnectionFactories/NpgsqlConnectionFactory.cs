using gravi_infrastructure.Data.Interfaces;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Npgsql;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_infrastructure.Data.ConnectionFactories
{
    /// <summary>
    /// Implements <see cref="IDbConnectionFactory"/> to create PostgreSQL database connections.
    /// </summary>
    public class NpgsqlConnectionFactory : IDbConnectionFactory
    {
        private readonly string _connectionString;
        private readonly ILogger<NpgsqlConnectionFactory> _logger;

        /// <summary>
        /// Initializes a new instance of the <see cref="PostgreSqlConnectionFactory"/> class.
        /// </summary>
        /// <param name="configuration">The application's configuration, used to retrieve the connection string.</param>
        /// <param name="logger">The logger instance for logging messages.</param>
        /// <exception cref="ArgumentNullException">Thrown if <paramref name="logger"/> is null.</exception>
        /// <exception cref="InvalidOperationException">Thrown if the "DefaultConnection" string is missing from configuration.</exception>
        public NpgsqlConnectionFactory( IConfiguration configuration, ILogger<NpgsqlConnectionFactory> logger)
        {
            // Retrieve the connection string from configuration.
            // Use null-coalescing with a null-check for more robust configuration handling.
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("Database connection string 'DefaultConnection' is missing from configuration.");

            // Ensure the logger is not null.
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        /// <summary>
        /// Creates and returns a new instance of <see cref="NpgsqlConnection"/>.
        /// </summary>
        /// <returns>A new <see cref="IDbConnection"/> instance for PostgreSQL.</returns>
        /// <exception cref="Exception">Catches and re-throws any exceptions that occur during connection creation, logging the error.</exception>
        public IDbConnection CreateConnection()
        {
            try
            {
                // Create a new NpgsqlConnection using the configured connection string.
                // Using the concrete NpgsqlConnection here as this factory is specific to PostgreSQL.
                var connection = new NpgsqlConnection(_connectionString);

                // Optional: Add logging for successful connection creation.
                _logger.LogInformation("Database connection created successfully.");

                return connection;
            }
            catch (Exception ex)
            {
                // Proper error handling and logging for connection creation failures.
                _logger.LogError(ex, "Failed to create database connection.");
                throw; // Re-throw the exception to propagate the error.
            }
        }
    }
}
