using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using gravi_domain.Entities;
using gravi_domain.Interfaces;
using gravi_infrastructure.Repositories.Base;
using Microsoft.Extensions.Logging;

namespace gravi_infrastructure.Repositories.NpgsqlRepositories
{
    public class PersonRepository : NpgsqlRepositoryBase<PersonRepository>, IPersonRepository
    {
        public PersonRepository(DbConnection connection, DbTransaction? transaction, ILogger<PersonRepository> logger) : base(connection, transaction, logger) { }

        public Task<(string Message, long? Result)> AddPerson(Person newPerson)
        {
            throw new NotImplementedException();
        }

        public Task<(string Message, bool Result)> DeletePerson(long personId)
        {
            throw new NotImplementedException();
        }

        public Task<Person?> FindPersonById(long personId)
        {
            throw new NotImplementedException();
        }

        public Task<(string Message, bool Result)> UpdatePerson(Person person)
        {
            throw new NotImplementedException();
        }
    }
}
