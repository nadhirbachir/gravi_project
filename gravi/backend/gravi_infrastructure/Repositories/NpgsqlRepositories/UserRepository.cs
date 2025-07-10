using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using gravi_domain.Entities;
using gravi_domain.Interfaces;
using gravi_infrastructure.Repositories.Base;
using Npgsql;

namespace gravi_infrastructure.Repositories.NpgsqlRepositories
{
    public class UserRepository : NpgsqlRepositoryBase, IUserRepository
    {
        public UserRepository(NpgsqlConnection connection, NpgsqlTransaction? transaction) : base(connection, transaction) { }


    }
}
